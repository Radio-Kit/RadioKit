use crate::session::{ClientSession, DeviceSession, RelayMessage};
use ed25519_dalek::{Signature, VerifyingKey};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};

/// Compound key for sessions: (name, account).
type SessionKey = (String, String);

/// Core relay that holds device and client sessions and routes frames between them.
pub struct Relay {
    pub devices: Arc<Mutex<HashMap<SessionKey, DeviceSession>>>,
    pub clients: Arc<Mutex<HashMap<SessionKey, Vec<ClientSession>>>>,
    /// All public keys that have ever successfully authenticated (device register or client auth).
    authenticated_accounts: Arc<Mutex<HashSet<String>>>,
}

impl Relay {
    pub fn new() -> Self {
        Self {
            devices: Arc::new(Mutex::new(HashMap::new())),
            clients: Arc::new(Mutex::new(HashMap::new())),
            authenticated_accounts: Arc::new(Mutex::new(HashSet::new())),
        }
    }

    /// Verify an Ed25519 signature for a challenge-response auth flow.
    ///
    /// `account` is the hex-encoded 32-byte Ed25519 public key.
    /// `nonce` is the 32-byte challenge sent to the client.
    /// `signature_b64` is the base64-encoded signature over the nonce.
    ///
    /// Returns true if the signature is valid for any device registered under
    /// this account, or if no devices are registered (allows keyless setup).
    pub async fn verify_auth(&self, account: &str, nonce: &[u8; 32], signature_b64: &str) -> bool {
        // If no devices are registered for this account, we can't verify
        // (this shouldn't happen in normal use — device registers first)
        let devices = self.devices.lock().await;
        let has_account = devices.iter().any(|((_, acct), _)| acct == account);
        if !has_account {
            return false;
        }
        drop(devices); // Release lock before crypto

        // Decode hex public key (32 bytes)
        let pubkey_bytes = match hex::decode(account) {
            Ok(b) if b.len() == 32 => b,
            _ => return false,
        };
        let pubkey = match VerifyingKey::from_bytes(&pubkey_bytes.try_into().unwrap_or([0u8; 32])) {
            Ok(k) => k,
            Err(_) => return false,
        };

        // Decode base64 signature (64 bytes)
        let sig_bytes =
            match base64::Engine::decode(&base64::engine::general_purpose::STANDARD, signature_b64)
            {
                Ok(b) if b.len() == 64 => b,
                _ => return false,
            };
        let signature = match Signature::from_slice(&sig_bytes) {
            Ok(s) => s,
            Err(_) => return false,
        };

        // Verify the signature
        pubkey.verify_strict(nonce, &signature).is_ok()
    }

    /// Handle a `register` control message from a device.
    ///
    /// Expects JSON: `{"type":"register","name":"...","account":"..."}`.
    /// Returns a JSON response string and a bool indicating whether to keep the connection alive.
    pub async fn handle_register(
        &self,
        name: &str,
        account: &str,
        tx: mpsc::UnboundedSender<RelayMessage>,
    ) -> (String, bool) {
        let key = (name.to_string(), account.to_string());
        let mut devices = self.devices.lock().await;

        // Remove existing session with the same key (re-registration)
        devices.remove(&key);

        devices.insert(
            key,
            DeviceSession {
                name: name.to_string(),
                account: account.to_string(),
                tx,
            },
        );

        let resp = serde_json::json!({
            "type": "registered",
            "ok": true,
            "sid": uuid_v4_short()
        });
        (resp.to_string(), true)
    }

    /// Handle a `join` control message from a client.
    ///
    /// Expects JSON: `{"type":"join","device":"...","account":"..."}`.
    /// Returns a JSON response string and a bool indicating whether to keep the connection alive.
    pub async fn handle_join(
        &self,
        device_name: &str,
        account: &str,
        tx: mpsc::UnboundedSender<RelayMessage>,
    ) -> (String, bool) {
        let device_key = (device_name.to_string(), account.to_string());
        let devices = self.devices.lock().await;

        if let Some(device) = devices.get(&device_key) {
            // Add client to the device's client list
            let client_key = (device_name.to_string(), account.to_string());
            let mut clients = self.clients.lock().await;
            let client_list = clients.entry(client_key).or_default();
            client_list.push(ClientSession {
                account: account.to_string(),
                tx: tx.clone(),
            });

            // Forward client_joined to the device
            let client_joined = serde_json::json!({
                "type": "client_joined",
                "account": account,
                "sid": uuid_v4_short()
            });
            let _ = device
                .tx
                .send(RelayMessage::Text(client_joined.to_string()));

            let resp = serde_json::json!({
                "type": "joined",
                "ok": true,
                "device": device_name,
                "deviceName": device.name
            });
            (resp.to_string(), true)
        } else {
            let resp = serde_json::json!({
                "type": "joined",
                "ok": false,
                "error": "device_not_found"
            });
            (resp.to_string(), true)
        }
    }

    /// Handle a `list_devices` control message from a client.
    ///
    /// Expects JSON: `{"type":"list_devices","account":"..."}`.
    /// Returns a list of device names currently registered for this account.
    pub async fn handle_list_devices(&self, account: &str) -> Vec<String> {
        let devices = self.devices.lock().await;
        devices
            .iter()
            .filter(|((_, acct), _)| acct == account)
            .map(|((name, _), _)| name.clone())
            .collect()
    }

    /// Route a binary frame from a sender to its paired peers.
    ///
    /// - If the sender is a device, forward to all linked clients.
    /// - If the sender is a client, forward to the linked device.
    /// The first byte of data is the protocol type byte (0x55/0xAA/0xBB/0xDD).
    pub async fn route_data(&self, data: Vec<u8>, key: SessionKey, is_device: bool) {
        if is_device {
            // Device → all linked clients
            let clients = self.clients.lock().await;
            if let Some(client_list) = clients.get(&key) {
                for client in client_list {
                    let _ = client.tx.send(RelayMessage::Binary(data.clone()));
                }
            }
        } else {
            // Client → linked device
            let devices = self.devices.lock().await;
            if let Some(device) = devices.get(&key) {
                let _ = device.tx.send(RelayMessage::Binary(data));
            }
        }
    }

    /// Notify all clients of a device that its status changed.
    pub async fn notify_device_status(&self, key: &SessionKey, status: &str) {
        let status_msg = serde_json::json!({
            "type": "device_status",
            "id": key.0,
            "status": status
        });
        let clients = self.clients.lock().await;
        if let Some(client_list) = clients.get(key) {
            for client in client_list {
                let _ = client.tx.send(RelayMessage::Text(status_msg.to_string()));
            }
        }
    }

    /// Remove a device session by key.
    pub async fn remove_device(&self, key: &SessionKey) {
        let mut devices = self.devices.lock().await;
        devices.remove(key);
        self.notify_device_status(key, "offline").await;
    }

    /// Remove a client session from the given client list.
    pub async fn remove_client(&self, key: &SessionKey, tx: &mpsc::UnboundedSender<RelayMessage>) {
        let mut clients = self.clients.lock().await;
        if let Some(client_list) = clients.get_mut(key) {
            client_list.retain(|c| !c.tx.same_channel(tx));
            if client_list.is_empty() {
                clients.remove(key);
            }
        }
    }

    /// Return the count of unique accounts with at least one registered device.
    pub async fn active_accounts(&self) -> usize {
        let devices = self.devices.lock().await;
        let mut accounts = std::collections::HashSet::new();
        for (_, acct) in devices.keys() {
            accounts.insert(acct.clone());
        }
        accounts.len()
    }

    /// Check whether this account already has any registered devices.
    pub async fn is_new_account(&self, account: &str) -> bool {
        let devices = self.devices.lock().await;
        !devices.keys().any(|(_, acct)| acct == account)
    }

    /// Record a public key as having successfully authenticated.
    /// Called after device registration and after client auth_response.
    pub async fn record_authenticated_account(&self, account: &str) {
        let mut accounts = self.authenticated_accounts.lock().await;
        accounts.insert(account.to_string());
    }

    /// Return the total number of unique public keys that have ever authenticated.
    pub async fn total_accounts_count(&self) -> usize {
        let accounts = self.authenticated_accounts.lock().await;
        accounts.len()
    }

    /// Return the set of public keys that have ever authenticated (for display).
    pub async fn authenticated_accounts_keys(&self) -> Vec<String> {
        let accounts = self.authenticated_accounts.lock().await;
        accounts.iter().cloned().collect()
    }
}

/// Generate a short unique session ID (8 hex chars).
pub fn uuid_v4_short() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_nanos();
    format!("{:08x}", nanos)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
    use tokio::sync::mpsc;

    /// Helper: create a relay and a device session, returning the relay,
    /// the device key, and the device's rx channel.
    async fn setup_device(
        relay: &Relay,
        name: &str,
        account: &str,
    ) -> (SessionKey, mpsc::UnboundedReceiver<RelayMessage>) {
        let (tx, rx) = mpsc::unbounded_channel();
        let (resp, _) = relay.handle_register(name, account, tx).await;
        let parsed: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["type"], "registered");
        assert_eq!(parsed["ok"], true);
        ((name.to_string(), account.to_string()), rx)
    }

    /// Helper: create a relay and a client session, returning the client's rx channel.
    /// Panics if the device doesn't exist.
    async fn setup_client(
        relay: &Relay,
        device_name: &str,
        account: &str,
    ) -> mpsc::UnboundedReceiver<RelayMessage> {
        let (tx, rx) = mpsc::unbounded_channel();
        let (resp, _) = relay.handle_join(device_name, account, tx).await;
        let parsed: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["type"], "joined");
        assert_eq!(parsed["ok"], true);
        rx
    }

    // ── handle_register tests ────────────────────────────────────────────────

    #[tokio::test]
    async fn test_register_device() {
        let relay = Relay::new();
        let (tx, _rx) = mpsc::unbounded_channel();
        let (resp, keep_alive) = relay
            .handle_register("test_device", "test_account", tx)
            .await;

        assert!(keep_alive);
        let parsed: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["type"], "registered");
        assert_eq!(parsed["ok"], true);
        assert!(parsed["sid"].as_str().unwrap_or("").len() == 8);

        // Verify device is stored
        let devices = relay.devices.lock().await;
        let key = ("test_device".to_string(), "test_account".to_string());
        assert!(devices.contains_key(&key));
        assert_eq!(devices[&key].name, "test_device");
        assert_eq!(devices[&key].account, "test_account");
    }

    #[tokio::test]
    async fn test_register_duplicate_replaces() {
        let relay = Relay::new();
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();

        // Register twice with the same key
        let (_, _) = relay.handle_register("device", "acct", tx1).await;
        let (_, _) = relay.handle_register("device", "acct", tx2).await;

        let devices = relay.devices.lock().await;
        let key = ("device".to_string(), "acct".to_string());
        assert!(devices.contains_key(&key));
        // Only one entry (replaced, not duplicated)
        assert_eq!(devices.len(), 1);
    }

    #[tokio::test]
    async fn test_register_multiple_devices() {
        let relay = Relay::new();
        let (tx1, _) = mpsc::unbounded_channel();
        let (tx2, _) = mpsc::unbounded_channel();

        let (_, _) = relay.handle_register("device_a", "acct1", tx1).await;
        let (_, _) = relay.handle_register("device_b", "acct2", tx2).await;

        let devices = relay.devices.lock().await;
        assert_eq!(devices.len(), 2);
    }

    // ── handle_join tests ────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_join_existing_device() {
        let relay = Relay::new();
        let (device_key, mut device_rx) = setup_device(&relay, "rc_car", "user1").await;

        let (client_tx, mut client_rx) = mpsc::unbounded_channel();
        let (resp, keep_alive) = relay.handle_join("rc_car", "user1", client_tx).await;

        assert!(keep_alive);
        let parsed: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["type"], "joined");
        assert_eq!(parsed["ok"], true);
        assert_eq!(parsed["device"], "rc_car");
        assert_eq!(parsed["deviceName"], "rc_car");

        // Device should have received a client_joined notification
        let msg = device_rx.recv().await;
        match msg {
            Some(RelayMessage::Text(text)) => {
                let parsed: Value = serde_json::from_str(&text).unwrap();
                assert_eq!(parsed["type"], "client_joined");
                assert_eq!(parsed["account"], "user1");
            }
            _ => panic!("Expected Text message"),
        }

        // Client should not have received any message yet
        let msg = client_rx.try_recv();
        assert!(msg.is_err()); // channel empty
    }

    #[tokio::test]
    async fn test_join_nonexistent_device() {
        let relay = Relay::new();
        let (tx, _rx) = mpsc::unbounded_channel();
        let (resp, keep_alive) = relay.handle_join("ghost_device", "user1", tx).await;

        assert!(keep_alive);
        let parsed: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["type"], "joined");
        assert_eq!(parsed["ok"], false);
        assert_eq!(parsed["error"], "device_not_found");
    }

    #[tokio::test]
    async fn test_join_wrong_account() {
        let relay = Relay::new();
        let (_, _) = relay
            .handle_register(
                "device",
                "account_a",
                mpsc::unbounded_channel::<RelayMessage>().0,
            )
            .await;

        // Try to join with different account
        let (tx, _rx) = mpsc::unbounded_channel();
        let (resp, _) = relay.handle_join("device", "account_b", tx).await;
        let parsed: Value = serde_json::from_str(&resp).unwrap();
        assert_eq!(parsed["ok"], false);
        assert_eq!(parsed["error"], "device_not_found");
    }

    // ── route_data tests ─────────────────────────────────────────────────────

    #[tokio::test]
    async fn test_route_data_device_to_client() {
        let relay = Relay::new();
        let (device_key, _device_rx) = setup_device(&relay, "device", "acct").await;
        let mut client_rx = setup_client(&relay, "device", "acct").await;

        let frame: Vec<u8> = vec![0x55, 0x01, 0x02, 0x03];
        relay.route_data(frame.clone(), device_key, true).await;

        // Client should receive the frame
        let msg = client_rx.recv().await;
        match msg {
            Some(RelayMessage::Binary(data)) => {
                assert_eq!(data, frame);
            }
            _ => panic!("Expected Binary message"),
        }
    }

    #[tokio::test]
    async fn test_route_data_client_to_device() {
        let relay = Relay::new();
        let (device_key, mut device_rx) = setup_device(&relay, "device", "acct").await;
        let (_, _) = relay
            .handle_join(
                "device",
                "acct",
                mpsc::unbounded_channel::<RelayMessage>().0,
            )
            .await;

        // Drain client_joined message from device
        let _ = device_rx.recv().await;

        let frame: Vec<u8> = vec![0x55, 0x05, 0x00];
        relay.route_data(frame.clone(), device_key, false).await;

        // Device should receive the frame
        let msg = device_rx.recv().await;
        match msg {
            Some(RelayMessage::Binary(data)) => {
                assert_eq!(data, frame);
            }
            _ => panic!("Expected Binary message"),
        }
    }

    #[tokio::test]
    async fn test_route_data_multiple_clients() {
        let relay = Relay::new();
        let (device_key, _device_rx) = setup_device(&relay, "device", "acct").await;

        // Two clients join
        let mut client_rx1 = setup_client(&relay, "device", "acct").await;
        let mut client_rx2 = setup_client(&relay, "device", "acct").await;

        // Device receives client_joined for each client in unbounded channel.
        // No drain needed since channel is unbounded.

        let frame: Vec<u8> = vec![0x55, 0x10];
        relay.route_data(frame.clone(), device_key, true).await;

        // Both clients should receive the frame
        let msg1 = client_rx1.recv().await;
        let msg2 = client_rx2.recv().await;

        match (msg1, msg2) {
            (Some(RelayMessage::Binary(d1)), Some(RelayMessage::Binary(d2))) => {
                assert_eq!(d1, frame);
                assert_eq!(d2, frame);
            }
            _ => panic!("Expected Binary messages"),
        }
    }

    #[tokio::test]
    async fn test_route_data_device_without_clients() {
        let relay = Relay::new();
        let (device_key, _device_rx) = setup_device(&relay, "device", "acct").await;

        // Device sends data but no clients are connected
        let frame: Vec<u8> = vec![0xAA, 0x01];
        relay.route_data(frame, device_key, true).await;
        // Should not panic — just no-op
    }

    #[tokio::test]
    async fn test_route_data_client_without_device() {
        let relay = Relay::new();
        let key = ("phantom".to_string(), "acct".to_string());

        let frame: Vec<u8> = vec![0x55, 0x01];
        relay.route_data(frame, key, false).await;
        // Should not panic — just no-op
    }

    // ── remove_device / remove_client tests ────────────────────────────────────

    #[tokio::test]
    async fn test_remove_device_notifies_clients() {
        let relay = Relay::new();
        let (device_key, _device_rx) = setup_device(&relay, "device", "acct").await;
        let mut client_rx = setup_client(&relay, "device", "acct").await;

        relay.remove_device(&device_key).await;

        // Devices map should be empty
        assert!(relay.devices.lock().await.is_empty());

        // Client should receive device_status: offline
        let msg = client_rx.recv().await;
        match msg {
            Some(RelayMessage::Text(text)) => {
                let parsed: Value = serde_json::from_str(&text).unwrap();
                assert_eq!(parsed["type"], "device_status");
                assert_eq!(parsed["status"], "offline");
                assert_eq!(parsed["id"], "device");
            }
            _ => panic!("Expected Text message"),
        }
    }

    #[tokio::test]
    async fn test_remove_client_cleans_up() {
        let relay = Relay::new();
        let (_device_key, _device_rx) = setup_device(&relay, "device", "acct").await;

        let client_key = ("device".to_string(), "acct".to_string());
        let (client_tx, _client_rx) = mpsc::unbounded_channel();
        let (_, _) = relay.handle_join("device", "acct", client_tx.clone()).await;

        // Remove the client
        relay.remove_client(&client_key, &client_tx).await;

        // Clients map should be empty
        assert!(relay.clients.lock().await.is_empty());
    }

    #[tokio::test]
    async fn test_remove_client_preserves_other_clients() {
        let relay = Relay::new();
        let (_device_key, _device_rx) = setup_device(&relay, "device", "acct").await;

        let client_key = ("device".to_string(), "acct".to_string());
        let (tx1, _rx1) = mpsc::unbounded_channel();
        let (tx2, _rx2) = mpsc::unbounded_channel();
        let (_, _) = relay.handle_join("device", "acct", tx1.clone()).await;
        let (_, _) = relay.handle_join("device", "acct", tx2.clone()).await;

        // Remove first client only
        relay.remove_client(&client_key, &tx1).await;

        let clients = relay.clients.lock().await;
        assert!(clients.contains_key(&client_key));
        assert_eq!(clients[&client_key].len(), 1);
    }

    // ── notify_device_status tests ────────────────────────────────────────────

    #[tokio::test]
    async fn test_notify_device_status() {
        let relay = Relay::new();
        let (_device_key, _device_rx) = setup_device(&relay, "device", "acct").await;
        let mut client_rx = setup_client(&relay, "device", "acct").await;

        let key = ("device".to_string(), "acct".to_string());
        relay.notify_device_status(&key, "online").await;

        let msg = client_rx.recv().await;
        match msg {
            Some(RelayMessage::Text(text)) => {
                let parsed: Value = serde_json::from_str(&text).unwrap();
                assert_eq!(parsed["type"], "device_status");
                assert_eq!(parsed["status"], "online");
            }
            _ => panic!("Expected Text message"),
        }
    }

    #[tokio::test]
    async fn test_notify_device_status_no_clients() {
        let relay = Relay::new();
        let key = ("device".to_string(), "acct".to_string());
        // No device or clients registered — should not panic
        relay.notify_device_status(&key, "offline").await;
    }

    // ── Integration: full lifecycle ───────────────────────────────────────────

    #[tokio::test]
    async fn test_full_device_client_lifecycle() {
        let relay = Relay::new();

        // 1. Device registers
        let (device_key, mut device_rx) = setup_device(&relay, "sensor", "team_a").await;

        // 2. First client joins
        let mut client1_rx = setup_client(&relay, "sensor", "team_a").await;
        // Device receives client_joined
        let msg = device_rx.recv().await;
        assert!(matches!(msg, Some(RelayMessage::Text(_))));

        // 3. Client sends a command to device
        let cmd: Vec<u8> = vec![0x55, 0x12, 0x34];
        relay
            .route_data(cmd.clone(), device_key.clone(), false)
            .await;
        let device_msg = device_rx.recv().await;
        assert!(matches!(device_msg, Some(RelayMessage::Binary(d)) if d == cmd));

        // 4. Device sends telemetry to client
        let tele: Vec<u8> = vec![0x55, 0x1E, 0x64];
        relay
            .route_data(tele.clone(), device_key.clone(), true)
            .await;
        let client_msg = client1_rx.recv().await;
        assert!(matches!(client_msg, Some(RelayMessage::Binary(d)) if d == tele));

        // 5. Second client joins
        let mut client2_rx = setup_client(&relay, "sensor", "team_a").await;

        // 6. Device broadcasts to both clients
        let broadcast: Vec<u8> = vec![0x55, 0x1E, 0x00, 0x42];
        relay
            .route_data(broadcast.clone(), device_key.clone(), true)
            .await;
        let c1 = client1_rx.recv().await;
        let c2 = client2_rx.recv().await;
        assert!(matches!(c1, Some(RelayMessage::Binary(d)) if d == broadcast));
        assert!(matches!(c2, Some(RelayMessage::Binary(d)) if d == broadcast));

        // 7. Device disconnects — clients get offline notification
        relay.remove_device(&device_key).await;
        let offline = client1_rx.recv().await;
        assert!(matches!(offline, Some(RelayMessage::Text(t)) if t.contains("offline")));
    }
}

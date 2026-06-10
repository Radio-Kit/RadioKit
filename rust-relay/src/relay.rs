use crate::session::{ClientSession, DeviceSession, RelayMessage};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};

/// Compound key for sessions: (name, account).
type SessionKey = (String, String);

/// Core relay that holds device and client sessions and routes frames between them.
pub struct Relay {
    pub devices: Arc<Mutex<HashMap<SessionKey, DeviceSession>>>,
    pub clients: Arc<Mutex<HashMap<SessionKey, Vec<ClientSession>>>>,
}

impl Relay {
    pub fn new() -> Self {
        Self {
            devices: Arc::new(Mutex::new(HashMap::new())),
            clients: Arc::new(Mutex::new(HashMap::new())),
        }
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
            let _ = device.tx.send(RelayMessage::Text(client_joined.to_string()));

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

    /// Route a binary frame from a sender to its paired peers.
    ///
    /// - If the sender is a device, forward to all linked clients.
    /// - If the sender is a client, forward to the linked device.
    /// The first byte of data is the protocol type byte (0x55/0xAA/0xBB/0xDD).
    pub async fn route_data(
        &self,
        data: Vec<u8>,
        key: SessionKey,
        is_device: bool,
    ) {
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
            client_list.retain(|c| c.tx.same_channel(tx));
            if client_list.is_empty() {
                clients.remove(key);
            }
        }
    }
}

/// Generate a short unique session ID (8 hex chars).
fn uuid_v4_short() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .subsec_nanos();
    format!("{:08x}", nanos)
}

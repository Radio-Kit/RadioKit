mod relay;
mod session;
mod rate_limiter;

use futures_util::{SinkExt, StreamExt};
use rand::RngCore;
use rate_limiter::RateLimiter;
use relay::Relay;
use session::RelayMessage;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_tungstenite::accept_async;
use tokio_tungstenite::tungstenite::Message;

const DEFAULT_PORT: u16 = 443;

#[tokio::main]
async fn main() {
    let port = std::env::var("RADIOKIT_PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(DEFAULT_PORT);

    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await.expect("Failed to bind TCP listener");
    eprintln!("RadioKit Relay listening on {}", addr);

    let relay = Arc::new(Relay::new());
    let rate_limiter = Arc::new(RateLimiter::new());

    while let Ok((stream, peer_addr)) = listener.accept().await {
        let relay = relay.clone();
        let rate_limiter = rate_limiter.clone();
        tokio::spawn(handle_connection(stream, peer_addr, relay, rate_limiter));
    }
}

/// Handle a single WebSocket connection.
async fn handle_connection(
    stream: TcpStream,
    peer_addr: SocketAddr,
    relay: Arc<Relay>,
    rate_limiter: Arc<RateLimiter>,
) {
    let ws_stream = match accept_async(stream).await {
        Ok(ws) => ws,
        Err(e) => {
            eprintln!("WebSocket handshake error from {}: {}", peer_addr, e);
            return;
        }
    };

    let (ws_write, ws_read) = ws_stream.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<RelayMessage>();

    // Spawn a forward task that dispatches RelayMessage variants to correct
    // WebSocket opcode — binary frames vs text control messages.
    let forward_handle = tokio::spawn(async move {
        let mut ws_write = ws_write;
        while let Some(msg) = rx.recv().await {
            let result = match msg {
                RelayMessage::Binary(data) => ws_write.send(Message::Binary(data)).await,
                RelayMessage::Text(text) => ws_write.send(Message::Text(text.into())).await,
            };
            if result.is_err() {
                break;
            }
        }
    });

    // Session state
    let mut session_key: Option<(String, String)> = None;
    let mut is_device = false;

    // Auth state for clients (challenge-response)
    let mut auth_nonce: Option<[u8; 32]> = None;
    let mut authenticated = false;

    // Helper to send a text response through the channel.
    let send_text = |tx: &mpsc::UnboundedSender<RelayMessage>, text: String| {
        let _ = tx.send(RelayMessage::Text(text));
    };

    // Helper to send a JSON response through the channel.
    let send_json = |tx: &mpsc::UnboundedSender<RelayMessage>, value: serde_json::Value| {
        let _ = tx.send(RelayMessage::Text(value.to_string()));
    };

    // Read loop — all outgoing messages go through the forward channel.
    let mut ws_read = ws_read;
    loop {
        let msg = ws_read.next().await;
        match msg {
            Some(Ok(Message::Text(text))) => {
                match serde_json::from_str::<serde_json::Value>(&text) {
                    Ok(json) => {
                        let msg_type = json["type"].as_str().unwrap_or("");

                        match msg_type {
                            "register" => {
                                let name = json["name"].as_str().unwrap_or("");
                                let account = json["account"].as_str().unwrap_or("");

                                if !rate_limiter.try_register_device(peer_addr) {
                                    send_json(&tx, serde_json::json!({
                                        "type": "error",
                                        "code": "rate_limited",
                                        "message": "Too many device connections from this IP"
                                    }));
                                    break;
                                }

                                let (resp, _) = relay.handle_register(name, account, tx.clone()).await;
                                session_key = Some((name.to_string(), account.to_string()));
                                is_device = true;
                                send_text(&tx, resp);
                            }

                            "auth_request" => {
                                let account = json["account"].as_str().unwrap_or("");
                                if account.is_empty() {
                                    send_json(&tx, serde_json::json!({
                                        "type": "auth_failed",
                                        "error": "missing_account"
                                    }));
                                    continue;
                                }

                                // Generate 32-byte random nonce
                                let mut nonce = [0u8; 32];
                                rand::rngs::OsRng.fill_bytes(&mut nonce);

                                auth_nonce = Some(nonce);

                                let nonce_b64 = base64::Engine::encode(
                                    &base64::engine::general_purpose::STANDARD,
                                    nonce,
                                );
                                send_json(&tx, serde_json::json!({
                                    "type": "auth_challenge",
                                    "nonce": nonce_b64
                                }));
                            }

                            "auth_response" => {
                                let signature_b64 = json["signature"].as_str().unwrap_or("");
                                let account = json["account"].as_str().unwrap_or("");
                                let nonce = match auth_nonce {
                                    Some(n) => n,
                                    None => {
                                        send_json(&tx, serde_json::json!({
                                            "type": "auth_failed",
                                            "error": "no_challenge"
                                        }));
                                        continue;
                                    }
                                };

                                if account.is_empty() || signature_b64.is_empty() {
                                    send_json(&tx, serde_json::json!({
                                        "type": "auth_failed",
                                        "error": "invalid_params"
                                    }));
                                    continue;
                                }

                                if relay.verify_auth(account, &nonce, signature_b64).await {
                                    authenticated = true;
                                    send_json(&tx, serde_json::json!({"type": "auth_ok"}));
                                } else {
                                    send_json(&tx, serde_json::json!({
                                        "type": "auth_failed",
                                        "error": "signature_mismatch"
                                    }));
                                }
                            }

                            "join" => {
                                if !authenticated && !is_device {
                                    send_json(&tx, serde_json::json!({
                                        "type": "error",
                                        "code": "not_authenticated",
                                        "message": "Clients must authenticate before joining"
                                    }));
                                    continue;
                                }

                                let device_name = json["device"].as_str().unwrap_or("");
                                let account = json["account"].as_str().unwrap_or("");

                                if !rate_limiter.try_register_client(peer_addr) {
                                    send_json(&tx, serde_json::json!({
                                        "type": "error",
                                        "code": "rate_limited",
                                        "message": "Too many client connections from this IP"
                                    }));
                                    break;
                                }

                                let (resp, _) = relay.handle_join(device_name, account, tx.clone()).await;
                                session_key = Some((device_name.to_string(), account.to_string()));
                                is_device = false;
                                send_text(&tx, resp);
                            }

                            "ping" => {
                                let ts = json["ts"].as_u64().unwrap_or(0);
                                send_json(&tx, serde_json::json!({"type": "pong", "ts": ts}));
                            }

                            "list_devices" => {
                                if !authenticated {
                                    send_json(&tx, serde_json::json!({
                                        "type": "error",
                                        "code": "not_authenticated",
                                        "message": "You must authenticate first"
                                    }));
                                    continue;
                                }
                                let account = json["account"].as_str().unwrap_or("");
                                let devices = relay.handle_list_devices(account).await;
                                send_json(&tx, serde_json::json!({
                                    "type": "device_list",
                                    "devices": devices
                                }));
                            }

                            "pong" => {
                                // Heartbeat response — nothing to do
                            }

                            _ => {
                                send_json(&tx, serde_json::json!({
                                    "type": "error",
                                    "code": "unknown_message",
                                    "message": format!("Unknown message type: {}", msg_type)
                                }));
                            }
                        }
                    }
                    Err(e) => {
                        send_json(&tx, serde_json::json!({
                            "type": "error",
                            "code": "invalid_json",
                            "message": format!("Invalid JSON: {}", e)
                        }));
                    }
                }
            }

            Some(Ok(Message::Binary(data))) => {
                if let Some(ref key) = session_key {
                    relay.route_data(data, key.clone(), is_device).await;
                }
            }

            Some(Ok(Message::Close(_))) => break,

            Some(Ok(Message::Ping(_))) => {
                // Auto-responded by tungstenite
            }

            Some(Err(e)) => {
                eprintln!("WebSocket error from {}: {}", peer_addr, e);
                break;
            }

            None => break,

            _ => {}
        }
    }

    // Cleanup
    if let Some(ref key) = session_key {
        if is_device {
            relay.remove_device(key).await;
            rate_limiter.unregister_device(peer_addr);
        } else {
            relay.remove_client(key, &tx).await;
            rate_limiter.unregister_client(peer_addr);
        }
    }

    forward_handle.abort();
}

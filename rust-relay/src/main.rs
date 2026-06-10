mod relay;
mod session;
mod rate_limiter;

use futures_util::{SinkExt, StreamExt};
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

                            "join" => {
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

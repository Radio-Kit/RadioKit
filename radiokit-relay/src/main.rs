mod rate_limiter;
mod relay;
mod relay_stats;
mod session;

use futures_util::{SinkExt, StreamExt};
use rand::RngCore;
use rate_limiter::RateLimiter;
use relay::Relay;
use relay_stats::{render_html, render_json, snapshot, RelayStats};
use session::RelayMessage;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_tungstenite::accept_async;
use tokio_tungstenite::tungstenite::Message;

const DEFAULT_PORT: u16 = 443;
const DEFAULT_STATS_PORT: u16 = 8080;

#[tokio::main]
async fn main() {
    let port = std::env::var("RADIOKIT_PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(DEFAULT_PORT);

    let stats_port = std::env::var("RADIOKIT_STATS_PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(DEFAULT_STATS_PORT);

    let addr = format!("0.0.0.0:{}", port);
    let ws_listener = TcpListener::bind(&addr)
        .await
        .expect("Failed to bind TCP listener");
    eprintln!("RadioKit Relay: WS on {}", addr);

    let relay = Arc::new(Relay::new());
    let rate_limiter = Arc::new(RateLimiter::new());
    let stats = Arc::new(RelayStats::new());

    // ── Stats HTTP server ────────────────────────────────────────────────
    let stats_addr = format!("0.0.0.0:{}", stats_port);
    let stats_listener = TcpListener::bind(&stats_addr)
        .await
        .expect("Failed to bind stats HTTP listener");
    eprintln!("RadioKit Relay: Stats HTTP on {}", stats_addr);

    let stats_for_http = stats.clone();
    let relay_for_http = relay.clone();
    let stats_handle = tokio::spawn(async move {
        loop {
            let (stream, peer) = match stats_listener.accept().await {
                Ok(c) => c,
                Err(_) => continue,
            };
            let relay = relay_for_http.clone();
            let stats = stats_for_http.clone();
            tokio::spawn(async move {
                handle_stats_http(stream, peer, relay, stats).await;
            });
        }
    });

    // ── WebSocket server ────────────────────────────────────────────────
    while let Ok((stream, peer_addr)) = ws_listener.accept().await {
        let relay = relay.clone();
        let rate_limiter = rate_limiter.clone();
        let stats = stats.clone();
        tokio::spawn(handle_connection(
            stream,
            peer_addr,
            relay,
            rate_limiter,
            stats,
        ));
    }

    let _ = stats_handle.await;
}

/// Handle an HTTP request on the stats port.
async fn handle_stats_http(
    mut stream: TcpStream,
    _peer: SocketAddr,
    relay: Arc<Relay>,
    stats: Arc<RelayStats>,
) {
    let mut buf = [0u8; 1024];
    let n = match stream.read(&mut buf).await {
        Ok(n) if n > 0 => n,
        _ => return,
    };

    let request = String::from_utf8_lossy(&buf[..n]);
    let path = request
        .lines()
        .next()
        .and_then(|l| l.split_whitespace().nth(1))
        .unwrap_or("/");

    let mut snap = snapshot(&stats);
    // Query relay for live account counts (overrides atomic counters)
    snap.current_accounts = relay.active_accounts().await;
    snap.total_accounts = relay.total_accounts_count().await as u64;

    let (body, content_type) = match path {
        "/api" | "/api/" => (render_json(&snap), "application/json"),
        _ => (render_html(&snap), "text/html"),
    };

    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: {}; charset=utf-8\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{}",
        content_type,
        body.len(),
        body
    );

    let _ = stream.write_all(response.as_bytes()).await;
}

/// Handle a single WebSocket connection.
async fn handle_connection(
    stream: TcpStream,
    peer_addr: SocketAddr,
    relay: Arc<Relay>,
    rate_limiter: Arc<RateLimiter>,
    stats: Arc<RelayStats>,
) {
    stats
        .total_connections
        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    stats
        .current_connections
        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);

    let ws_stream = match accept_async(stream).await {
        Ok(ws) => ws,
        Err(e) => {
            eprintln!("WebSocket handshake error from {}: {}", peer_addr, e);
            stats
                .current_connections
                .fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
            return;
        }
    };

    stats
        .current_clients
        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);

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
                                    stats
                                        .rate_limits_hit
                                        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "error",
                                            "code": "rate_limited",
                                            "message": "Too many device connections from this IP"
                                        }),
                                    );
                                    break;
                                }

                                let is_first_account = relay.is_new_account(account).await;
                                let (resp, _) =
                                    relay.handle_register(name, account, tx.clone()).await;
                                session_key = Some((name.to_string(), account.to_string()));
                                is_device = true;
                                relay.record_authenticated_account(account).await;
                                stats
                                    .total_devices_registered
                                    .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                stats
                                    .current_devices
                                    .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                if is_first_account {
                                    stats
                                        .total_accounts
                                        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                }
                                send_text(&tx, resp);
                            }

                            "auth_request" => {
                                let account = json["account"].as_str().unwrap_or("");
                                if account.is_empty() {
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "auth_failed",
                                            "error": "missing_account"
                                        }),
                                    );
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
                                send_json(
                                    &tx,
                                    serde_json::json!({
                                        "type": "auth_challenge",
                                        "nonce": nonce_b64
                                    }),
                                );
                            }

                            "auth_response" => {
                                let signature_b64 = json["signature"].as_str().unwrap_or("");
                                let account = json["account"].as_str().unwrap_or("");
                                let nonce = match auth_nonce {
                                    Some(n) => n,
                                    None => {
                                        send_json(
                                            &tx,
                                            serde_json::json!({
                                                "type": "auth_failed",
                                                "error": "no_challenge"
                                            }),
                                        );
                                        continue;
                                    }
                                };

                                if account.is_empty() || signature_b64.is_empty() {
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "auth_failed",
                                            "error": "invalid_params"
                                        }),
                                    );
                                    continue;
                                }

                                if relay.verify_auth(account, &nonce, signature_b64).await {
                                    authenticated = true;
                                    relay.record_authenticated_account(account).await;
                                    // Send device list immediately so clients don't need
                                    // a separate list_devices request.
                                    let devices = relay.handle_list_devices(account).await;
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "auth_ok",
                                            "devices": devices
                                        }),
                                    );
                                } else {
                                    stats
                                        .failed_auths
                                        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "auth_failed",
                                            "error": "signature_mismatch"
                                        }),
                                    );
                                }
                            }

                            "join" => {
                                if !authenticated && !is_device {
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "error",
                                            "code": "not_authenticated",
                                            "message": "Clients must authenticate before joining"
                                        }),
                                    );
                                    continue;
                                }

                                let device_name = json["device"].as_str().unwrap_or("");
                                let account = json["account"].as_str().unwrap_or("");

                                if !rate_limiter.try_register_client(peer_addr) {
                                    stats
                                        .rate_limits_hit
                                        .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "error",
                                            "code": "rate_limited",
                                            "message": "Too many client connections from this IP"
                                        }),
                                    );
                                    break;
                                }

                                let (resp, _) =
                                    relay.handle_join(device_name, account, tx.clone()).await;
                                session_key = Some((device_name.to_string(), account.to_string()));
                                is_device = false;
                                stats
                                    .total_clients_joined
                                    .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                                send_text(&tx, resp);
                            }

                            "ping" => {
                                let ts = json["ts"].as_u64().unwrap_or(0);
                                send_json(&tx, serde_json::json!({"type": "pong", "ts": ts}));
                            }

                            "list_devices" => {
                                if !authenticated {
                                    send_json(
                                        &tx,
                                        serde_json::json!({
                                            "type": "error",
                                            "code": "not_authenticated",
                                            "message": "You must authenticate first"
                                        }),
                                    );
                                    continue;
                                }
                                let account = json["account"].as_str().unwrap_or("");
                                let devices = relay.handle_list_devices(account).await;
                                send_json(
                                    &tx,
                                    serde_json::json!({
                                        "type": "device_list",
                                        "devices": devices
                                    }),
                                );
                            }

                            "pong" => {
                                // Heartbeat response — nothing to do
                            }

                            _ => {
                                send_json(
                                    &tx,
                                    serde_json::json!({
                                        "type": "error",
                                        "code": "unknown_message",
                                        "message": format!("Unknown message type: {}", msg_type)
                                    }),
                                );
                            }
                        }
                    }
                    Err(e) => {
                        send_json(
                            &tx,
                            serde_json::json!({
                                "type": "error",
                                "code": "invalid_json",
                                "message": format!("Invalid JSON: {}", e)
                            }),
                        );
                    }
                }
            }

            Some(Ok(Message::Binary(data))) => {
                let len = data.len();
                if let Some(ref key) = session_key {
                    relay.route_data(data, key.clone(), is_device).await;
                }
                stats
                    .total_bytes_routed
                    .fetch_add(len as u64, std::sync::atomic::Ordering::Relaxed);
                stats
                    .total_messages_routed
                    .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
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

    // Cleanup — remove session and decrement stats counters
    if let Some(ref key) = session_key {
        if is_device {
            relay.remove_device(key).await;
            rate_limiter.unregister_device(peer_addr);
            stats
                .current_devices
                .fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
        } else {
            relay.remove_client(key, &tx).await;
            rate_limiter.unregister_client(peer_addr);
        }
    }
    stats
        .current_clients
        .fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
    stats
        .current_connections
        .fetch_sub(1, std::sync::atomic::Ordering::Relaxed);

    forward_handle.abort();
}

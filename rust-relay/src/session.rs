use tokio::sync::mpsc;

/// Messages sent through the relay channel — distinguishes binary radio frames
/// from text JSON control messages so the WebSocket forward task can dispatch
/// on the correct opcode.
pub enum RelayMessage {
    /// Binary RadioKit protocol frame (type-byte prefixed).
    Binary(Vec<u8>),
    /// Text JSON control message (register, joined, client_joined, etc.).
    Text(String),
}

/// A connected ESP32 device.
pub struct DeviceSession {
    pub name: String,
    pub account: String,
    pub tx: mpsc::UnboundedSender<RelayMessage>,
}

/// A connected Flutter app client.
pub struct ClientSession {
    pub account: String,
    pub tx: mpsc::UnboundedSender<RelayMessage>,
}

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;

const DEFAULT_MAX_DEVICES_PER_IP: usize = 10;
const DEFAULT_MAX_CLIENTS_PER_IP: usize = 50;

/// Tracks connection counts per IP address.
pub struct RateLimiter {
    max_devices_per_ip: usize,
    max_clients_per_ip: usize,
    counts: Mutex<HashMap<SocketAddr, ConnectionCount>>,
}

struct ConnectionCount {
    device_count: AtomicUsize,
    client_count: AtomicUsize,
}

impl RateLimiter {
    pub fn new() -> Self {
        let max_dev = std::env::var("RADIOKIT_MAX_DEVICES_PER_IP")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(DEFAULT_MAX_DEVICES_PER_IP);

        let max_cli = std::env::var("RADIOKIT_MAX_CLIENTS_PER_IP")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(DEFAULT_MAX_CLIENTS_PER_IP);

        Self {
            max_devices_per_ip: max_dev,
            max_clients_per_ip: max_cli,
            counts: Mutex::new(HashMap::new()),
        }
    }

    /// Try to register a device connection from `addr`.
    /// Returns `true` if accepted, `false` if rate-limited.
    pub fn try_register_device(&self, addr: SocketAddr) -> bool {
        let mut counts = self.counts.lock().unwrap();
        let entry = counts.entry(addr).or_insert_with(|| ConnectionCount {
            device_count: AtomicUsize::new(0),
            client_count: AtomicUsize::new(0),
        });
        let current = entry.device_count.load(Ordering::Relaxed);
        if current >= self.max_devices_per_ip {
            return false;
        }
        entry.device_count.store(current + 1, Ordering::Relaxed);
        true
    }

    /// Try to register a client connection from `addr`.
    /// Returns `true` if accepted, `false` if rate-limited.
    pub fn try_register_client(&self, addr: SocketAddr) -> bool {
        let mut counts = self.counts.lock().unwrap();
        let entry = counts.entry(addr).or_insert_with(|| ConnectionCount {
            device_count: AtomicUsize::new(0),
            client_count: AtomicUsize::new(0),
        });
        let current = entry.client_count.load(Ordering::Relaxed);
        if current >= self.max_clients_per_ip {
            return false;
        }
        entry.client_count.store(current + 1, Ordering::Relaxed);
        true
    }

    /// Remove a device connection from `addr`.
    pub fn unregister_device(&self, addr: SocketAddr) {
        let mut counts = self.counts.lock().unwrap();
        if let Some(entry) = counts.get(&addr) {
            let current = entry.device_count.load(Ordering::Relaxed);
            if current > 1 {
                entry.device_count.store(current - 1, Ordering::Relaxed);
            } else {
                let client_count = entry.client_count.load(Ordering::Relaxed);
                if client_count == 0 {
                    counts.remove(&addr);
                } else {
                    entry.device_count.store(0, Ordering::Relaxed);
                }
            }
        }
    }

    /// Remove a client connection from `addr`.
    pub fn unregister_client(&self, addr: SocketAddr) {
        let mut counts = self.counts.lock().unwrap();
        if let Some(entry) = counts.get(&addr) {
            let current = entry.client_count.load(Ordering::Relaxed);
            if current > 1 {
                entry.client_count.store(current - 1, Ordering::Relaxed);
            } else {
                let device_count = entry.device_count.load(Ordering::Relaxed);
                if device_count == 0 {
                    counts.remove(&addr);
                } else {
                    entry.client_count.store(0, Ordering::Relaxed);
                }
            }
        }
    }
}

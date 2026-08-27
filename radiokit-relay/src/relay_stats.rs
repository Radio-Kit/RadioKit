use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;

/// Shared relay statistics, updated atomically from connection handlers.
pub struct RelayStats {
    pub total_devices_registered: AtomicU64,
    pub total_clients_joined: AtomicU64,
    pub total_bytes_routed: AtomicU64,
    pub total_messages_routed: AtomicU64,
    pub current_devices: AtomicUsize,
    pub current_clients: AtomicUsize,
    pub current_connections: AtomicUsize,
    pub total_connections: AtomicU64,
    pub total_accounts: AtomicU64,
    pub current_accounts: AtomicUsize,
    pub failed_auths: AtomicU64,
    pub rate_limits_hit: AtomicU64,
}

impl RelayStats {
    pub fn new() -> Self {
        Self {
            total_devices_registered: AtomicU64::new(0),
            total_clients_joined: AtomicU64::new(0),
            total_bytes_routed: AtomicU64::new(0),
            total_messages_routed: AtomicU64::new(0),
            current_devices: AtomicUsize::new(0),
            current_clients: AtomicUsize::new(0),
            current_connections: AtomicUsize::new(0),
            total_connections: AtomicU64::new(0),
            total_accounts: AtomicU64::new(0),
            current_accounts: AtomicUsize::new(0),
            failed_auths: AtomicU64::new(0),
            rate_limits_hit: AtomicU64::new(0),
        }
    }
}

/// Snapshot of stats at a point in time, for rendering.
pub struct StatsSnapshot {
    pub total_devices_registered: u64,
    pub total_clients_joined: u64,
    pub total_bytes_routed: u64,
    pub total_messages_routed: u64,
    pub current_devices: usize,
    pub current_clients: usize,
    pub current_connections: usize,
    pub total_connections: u64,
    pub total_accounts: u64,
    pub current_accounts: usize,
    pub failed_auths: u64,
    pub rate_limits_hit: u64,
}

pub fn snapshot(stats: &Arc<RelayStats>) -> StatsSnapshot {
    StatsSnapshot {
        total_devices_registered: stats.total_devices_registered.load(Ordering::Relaxed),
        total_clients_joined: stats.total_clients_joined.load(Ordering::Relaxed),
        total_bytes_routed: stats.total_bytes_routed.load(Ordering::Relaxed),
        total_messages_routed: stats.total_messages_routed.load(Ordering::Relaxed),
        current_devices: stats.current_devices.load(Ordering::Relaxed),
        current_clients: stats.current_clients.load(Ordering::Relaxed),
        current_connections: stats.current_connections.load(Ordering::Relaxed),
        total_connections: stats.total_connections.load(Ordering::Relaxed),
        total_accounts: stats.total_accounts.load(Ordering::Relaxed),
        current_accounts: stats.current_accounts.load(Ordering::Relaxed),
        failed_auths: stats.failed_auths.load(Ordering::Relaxed),
        rate_limits_hit: stats.rate_limits_hit.load(Ordering::Relaxed),
    }
}

pub fn bytes_human(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB"];
    let mut b = bytes as f64;
    let mut i = 0;
    while b >= 1024.0 && i < UNITS.len() - 1 {
        b /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{} {}", bytes, UNITS[i])
    } else {
        format!("{:.1} {}", b, UNITS[i])
    }
}

/// Render the full HTML page for the stats endpoint.
/// No templates, no frameworks, just raw strings and browser defaults.
pub fn render_html(stats: &StatsSnapshot) -> String {
    let routed = bytes_human(stats.total_bytes_routed);

    format!(
        r#"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RadioKit Relay</title>
<style>
  body {{
    font-family: -apple-system, system-ui, monospace;
    max-width: 640px;
    margin: 2em auto;
    padding: 0 1em;
    line-height: 1.6;
  }}
  h1 {{ font-size: 1.4em; }}
  h2 {{ font-size: 1.1em; margin-top: 1.5em; }}
  hr {{ border: none; border-top: 1px solid #ccc; }}
  table {{ width: 100%; border-collapse: collapse; }}
  td {{ padding: 2px 0; }}
  td:last-child {{ text-align: right; font-weight: bold; }}
  ul {{ padding-left: 1.5em; }}
  .ok {{ color: #090; }}
  .warn {{ color: #960; }}
  .err {{ color: #c00; }}
  .foot {{ margin-top: 2em; font-size: 0.85em; color: #888; }}
</style>
</head>
<body>
<h1>RadioKit Relay</h1>
<p class="ok">connected &mdash; {routed} relayed</p>
<hr>
<h2>Traffic</h2>
<table>
<tr><td>Bytes relayed</td><td>{routed}</td></tr>
<tr><td>Messages relayed</td><td>{msgs}</td></tr>
</table>
<h2>Active connections</h2>
<table>
<tr><td>Devices</td><td>{cur_dev}</td></tr>
<tr><td>Clients</td><td>{cur_cli}</td></tr>
<tr><td>Connections</td><td>{cur_conn}</td></tr>
</table>
<h2>Accounts</h2>
<table>
<tr><td>Active accounts</td><td>{cur_acct}</td></tr>
<tr><td>Total accounts (all time)</td><td>{tot_acct}</td></tr>
</table>
<h2>Errors</h2>
<table>
<tr><td>Failed auths</td><td>{failed_auths}</td></tr>
<tr><td>Rate limits hit</td><td>{rate_limits}</td></tr>
</table>
<hr>
<p class="foot">updates every second &middot; <a href="/">refresh</a></p>
<script>
(function() {{
  var p = window.location.pathname;
  if (p === '/api') {{
    document.title = 'RadioKit Relay (API)';
    return;
  }}
  setInterval(function() {{
    var r = new XMLHttpRequest();
    r.open('GET', '/api', true);
    r.onload = function() {{
      if (r.status === 200) {{
        var d = JSON.parse(r.responseText);
        var cells = document.querySelectorAll('td:last-child');
        var m = [
          d.total_bytes_routed, d.total_messages_routed,
          d.current_devices, d.current_clients, d.current_connections,
          d.current_accounts, d.total_accounts,
          d.failed_auths, d.rate_limits_hit
        ];
        for (var i = 0; i < cells.length && i < m.length; i++) {{
          cells[i].textContent = m[i];
        }}
      }}
    }};
    r.send();
  }}, 1000);
}})();
</script>
</body>
</html>"#,
        routed = routed,
        msgs = stats.total_messages_routed,
        cur_dev = stats.current_devices,
        cur_cli = stats.current_clients,
        cur_conn = stats.current_connections,
        cur_acct = stats.current_accounts,
        tot_acct = stats.total_accounts,
        failed_auths = stats.failed_auths,
        rate_limits = stats.rate_limits_hit,
    )
}

/// Render the JSON API response.
pub fn render_json(stats: &StatsSnapshot) -> String {
    serde_json::json!({
        "total_bytes_routed": stats.total_bytes_routed,
        "total_messages_routed": stats.total_messages_routed,
        "current_devices": stats.current_devices,
        "current_clients": stats.current_clients,
        "current_connections": stats.current_connections,
        "current_accounts": stats.current_accounts,
        "total_accounts": stats.total_accounts,
        "failed_auths": stats.failed_auths,
        "rate_limits_hit": stats.rate_limits_hit,
    })
    .to_string()
}

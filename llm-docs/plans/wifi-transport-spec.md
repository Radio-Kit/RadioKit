# WiFi Transport Specification

## Overview

Add a **WiFi transport** to RadioKit, making it a first-class transport alongside BLE and Serial. The ESP32 device acts as both a WiFi client (STA mode) and an access point (AP mode). The Flutter app connects to the device over a **raw TCP socket** on port **5555**, sending the same framed 0x55/0xAA/0xBB packets that BLE and Serial use.

**STA mode**: The device connects to a user-configured WiFi network.  
**AP mode**: The device creates its own WiFi network as a fallback when STA is unavailable. AP SSID = `RK_<device_name>`, AP password = the NVS connection password (`_nvsPwd`, min 8 chars enforced).

---

## 1. Mode of Operation

### 1.1 STA + AP Fallback

```
┌─────────────────────────────────────────────┐
│                 ESP32 Device                  │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         WiFi Transport                │   │
│  │                                       │   │
│  │  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │  STA Mode    │  │  AP Mode     │  │   │
│  │  │  (client)    │  │  (fallback)  │  │   │
│  │  └──────┬───────┘  └──────┬───────┘  │   │
│  │         │                  │          │   │
│  │         ▼                  ▼          │   │
│  │   ┌──────────────────────────────┐   │   │
│  │   │     TCP Server (port 5555)    │   │   │
│  │   └──────────────────────────────┘   │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │         mDNS Advertiser               │   │
│  │  _radiokit._tcp  port 5555           │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### 1.2 Boot sequence

1. On boot, read NVS for `rk_sta_ssid` and `rk_sta_pwd`.
2. If STA_SSID is set (non-empty), attempt to connect as a WiFi client:
   - Timeout: 15 seconds.
   - If STA connects successfully → start TCP server on port 5555 → start mDNS advertising.
   - If STA fails to connect → fall back to AP mode.
3. If STA_SSID is empty (first boot, no config) → start in AP mode immediately.
4. **AP mode parameters**:
   - SSID: `RK_<device_name>` (from NVS `rk_name` or compile-time default). **Truncated to 32 chars max**: `RK_` (3) + first 28 chars of device name.
   - Password: `_nvsPwd` (connection password from NVS). Must be ≥8 characters — enforced on the app side when configuring WiFi.
   - IP: `192.168.4.1` (ESP32 soft-AP default).
5. **Background STA retry**: When in AP mode (because STA wasn't available), periodically retry STA connection every 60 seconds. When STA connects successfully:
   - Stop AP mode + AP TCP server.
   - Start STA-mode TCP server on port 5555.
   - Re-start mDNS advertising (IP may have changed).
   - **Keep old TCP connections alive** — the app is already connected via the old IP and can discover the new IP via mDNS re-query or manual reconnection.
6. **WiFi mode**: Use `WiFi.mode(WIFI_AP_STA)` when running AP mode with background STA retry. Once STA connects and AP is stopped, switch to `WiFi.mode(WIFI_STA)`. During retry intervals, both AP and STA are active simultaneously.
7. Once a connection is established through one method (STA or AP), the other method is disabled to avoid conflicts.

### 1.3 Dual STA + AP simultaneous (future consideration)

Not implemented initially — STA and AP are mutually exclusive at runtime, with AP as fallback only.

---

## 2. Compile-Time Defaults (RK_Config)

Add to `RK_Config` in `RadioKitLib.h`:

```cpp
struct RK_Config {
    // ... existing fields ...
    
    // ── WiFi (new) ─────────────────────────────────
    const char* sta_ssid    = "";    // Default: empty = AP-only on first boot
    const char* sta_password = "";   // Default: empty
    // AP SSID is derived from config.name as "RK_<name>"
    // AP password is config.password (same as connection pwd)
};
```

These defaults are used when NVS is empty (first boot) or not available.

---

## 3. Transport Architecture

### 3.1 Arduino side: `RadioKitWiFi` class

A new file `arduino-library/src/connection/RadioKitWiFi.h` and `.cpp` implementing `RadioKitTransport`:

```cpp
class RadioKitWiFi : public RadioKitTransport {
public:
    void begin(const char* name, RK_PacketCallback cb) override;
    void setFsCallback(RK_FsPacketCallback cb) override;
    void setOtaCallback(RK_OtaPacketCallback cb) override;
    void update() override;
    void sendPacket(const uint8_t* buf, uint16_t len) override;
    bool isConnected() const override;
    int8_t getRssi() override;

    // WiFi-specific
    void setCredentials(const char* staSsid, const char* staPassword);
    bool isApMode() const;
    const char* getLocalIp() const;

private:
    // TCP server
    WiFiServer _server;
    WiFiClient _client;
    
    // Callbacks
    RK_PacketCallback _packetCb;
    RK_FsPacketCallback _fsCb;
    RK_OtaPacketCallback _otaCb;
    
    // State
    bool _apMode;
    unsigned long _lastPacketMs;
    unsigned long _lastByteMs;
    unsigned long _lastStaRetryMs;
    
    // Internal
    void _startAp(const char* ssid, const char* password);
    bool _connectSta(const char* ssid, const char* password);
    void _feedBytes(const uint8_t* data, size_t len);
};
```

### 3.2 Registration in `RadioKitClass`

```cpp
// New method
void startWiFi();

// Internal pointer (same pattern as BLE/Serial)
RadioKitWiFi RadioKitWiFiInstance;
```

Called by user sketch:
```cpp
RadioKit.begin();
RadioKit.startWiFi();  // instead of startBLE() or startSerial()
```

### 3.3 Compile-time inclusion

WiFi is always compiled in when using ESP32 (the `WiFi.h` and `ESPmDNS.h` libraries are part of the Arduino core). No special compile-time flag needed — it's a transport just like BLE and Serial. Users choose at compile time via `startWiFi()` vs `startBLE()` vs `startSerial()`.

### 3.4 Feature bitmask (conditional)

The `RK_FEATURE_WIFI` bit (bit 4) is set **only** when `startWiFi()` has been called (i.e., `_transport == &RadioKitWiFiInstance`). This prevents the Flutter app from offering WiFi connection options when the firmware uses BLE or Serial.

```
Bit 4: kFeatureWiFi = 1 << 4  — WiFi transport active
```

---

## 4. TCP Protocol

### 4.1 Wire format

Raw framed 0x55/0xAA/0xBB packets are sent **unmodified** over TCP. The same packet parsers (0x55 widget, 0xAA FS, 0xBB OTA) work identically.

**Framing within TCP**: Each packet is self-framing (the length field is in the packet header). The TCP receiver uses the same byte-feeder state machines that BLE/Serial use — feed bytes one at a time, the state machine extracts complete frames.

The TCP server **does not** add any additional framing headers or CRCs — the existing packet CRCs (CRC-16 for 0x55, no CRC for 0xAA/0xBB) are sufficient for a reliable TCP transport.

### 4.2 Connection model

- **Single connection only**: The TCP server accepts only one client at a time.
  - First connection is the controller.
  - Subsequent connections are rejected (connection dropped immediately).
- **Reconnection**: If the client disconnects, the server immediately accepts a new connection.

### 4.3 mDNS advertisement

**Arduino dependency**: `#include <ESPmDNS.h>` (part of ESP32 Arduino core, no extra library needed).

**Initialization** (in `RadioKitWiFi::begin()`):

```cpp
#include <ESPmDNS.h>

MDNS.begin("radiokit");
MDNS.addService("_radiokit", "_tcp", 5555);
MDNS.addServiceTxt("_radiokit", "_tcp", "name", deviceName);
MDNS.addServiceTxt("_radiokit", "_tcp", "mode", "ap");  // or "sta"
MDNS.addServiceTxt("_radiokit", "_tcp", "ip", WiFi.localIP().toString().c_str());
```

**Transition from AP → STA**: Call `MDNS.end()` then re-initialize with updated TXT records.

**Service type**:
```
Service type: _radiokit._tcp
Port:         5555
TXT records:
  name=<device_name>     (e.g. "RC_CONTROLLER")
  mode=<sta|ap>          ("sta" or "ap" depending on current mode)
  ip=<local_ip>          (e.g. "192.168.1.42" or "192.168.4.1")
```

**Flutter side**: Use the `multicast_dns` package for service discovery.

### 4.4 Connection check (`isConnected`)

```cpp
bool RadioKitWiFi::isConnected() const {
    return _client && _client.connected() && (millis() - _lastPacketMs) < TIMEOUT_MS;
}
```

Where `TIMEOUT_MS` = 5000 (5 seconds). If no packet received in 5 seconds, treat as disconnected. The app sends PING/PONG as heartbeat.

### 4.5 RSSI

```cpp
int8_t RadioKitWiFi::getRssi() {
    if (_apMode) return 0;  // No RSSI in AP mode
    return WiFi.RSSI();      // WiFi library RSSI for STA mode
}
```

---

## 5. NVS Config

### 5.1 New NVS keys

| Key | C++ constant | Purpose | Max length |
|---|---|---|---|
| `rk_sta_ssid` | `RK_NVS_KEY_STA_SSID` | STA WiFi SSID | 32 |
| `rk_sta_pwd` | `RK_NVS_KEY_STA_PWD` | STA WiFi password | 64 |

```cpp
#define RK_NVS_KEY_STA_SSID    "rk_sta_ssid"
#define RK_NVS_KEY_STA_PWD     "rk_sta_pwd"
```

### 5.2 Firmware buffers

Add to `RadioKitClass`:

```cpp
char _nvsStaSsid[RADIOKIT_MAX_SSID + 1];  // 32+1 = 33
char _nvsStaPwd[RADIOKIT_MAX_WIFI_PWD + 1]; // 64+1 = 65
```

New limits in `RadioKitConfig.h`:

```cpp
#define RADIOKIT_MAX_SSID      32
#define RADIOKIT_MAX_WIFI_PWD  64
```

### 5.3 First-boot behaviour

On first boot (NVS empty, detected by missing `rk_name` key):
- Write compile-time defaults to NVS for WiFi keys just like for name/desc/pwd:
  ```cpp
  RKNvs::writeString(RK_NVS_KEY_STA_SSID, config.sta_ssid ? config.sta_ssid : "");
  RKNvs::writeString(RK_NVS_KEY_STA_PWD, config.sta_password ? config.sta_password : "");
  ```
- This ensures `_syncNvsToBuffers()` always finds the keys during NVS reload.
- If compile-time defaults are also empty → device starts in AP-only mode.

### 5.4 `_syncNvsToBuffers()` changes

Load `rk_sta_ssid` and `rk_sta_pwd` from NVS, falling back to compile-time defaults:

```cpp
if (!RKNvs::readString(RK_NVS_KEY_STA_SSID, _nvsStaSsid, sizeof(_nvsStaSsid))) {
    strncpy(_nvsStaSsid, config.sta_ssid ? config.sta_ssid : "", sizeof(_nvsStaSsid) - 1);
}
if (!RKNvs::readString(RK_NVS_KEY_STA_PWD, _nvsStaPwd, sizeof(_nvsStaPwd))) {
    strncpy(_nvsStaPwd, config.sta_password ? config.sta_password : "", sizeof(_nvsStaPwd) - 1);
}
```

---

## 6. SET_WIFI Command (CMD 0x1C)

### 6.1 New command IDs

```cpp
// In RadioKitProtocol.h
#define RK_CMD_SET_WIFI         0x1C  // App → Arduino: write WiFi creds to NVS
```

### 6.2 Dart side

```dart
// In protocol.dart
const int kCmdSetWifi = 0x1C;
```

### 6.3 Payload format

Same field-mask approach as SET_CONF (0x19):

```
Payload:
  [fieldMask(2 LE)]
  [SSID_LEN(1)] [SSID...]        // if mask bit 0 is set
  [PWD_LEN(1)] [PWD...]          // if mask bit 1 is set

Field mask bits:
  Bit 0: SSID present
  Bit 1: Password present
  Bit 7: Error (ACK only)
```

### 6.4 Handler

```cpp
void RadioKitClass::_handleSetWifi(const uint8_t* payload, uint16_t len) {
    if (!_nvsActive || len < 2) return;
    
    uint16_t fieldMask = (uint16_t)payload[0] | ((uint16_t)payload[1] << 8);
    uint16_t offset = 2;
    
    // STA SSID
    if (fieldMask & RK_SET_WIFI_SSID) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_SSID) strLen = RADIOKIT_MAX_SSID;
            if (offset + strLen <= len) {
                memcpy(_nvsStaSsid, &payload[offset], strLen);
                _nvsStaSsid[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_STA_SSID, _nvsStaSsid);
            }
            offset += strLen;
        }
    }
    
    // STA Password
    if (fieldMask & RK_SET_WIFI_PWD) {
        if (offset < len) {
            uint8_t strLen = payload[offset++];
            if (strLen > RADIOKIT_MAX_WIFI_PWD) strLen = RADIOKIT_MAX_WIFI_PWD;
            if (offset + strLen <= len) {
                memcpy(_nvsStaPwd, &payload[offset], strLen);
                _nvsStaPwd[strLen] = '\0';
                RKNvs::writeString(RK_NVS_KEY_STA_PWD, _nvsStaPwd);
            }
            offset += strLen;
        }
    }
    
    RKNvs::commit();
    
    // Send ACK
    uint16_t ackLen = rk_buildPacket(_txBuf, RK_CMD_ACK, (uint8_t*)&fieldMask, 1);
    _sendPacket(ackLen);
    
    // Auto-reboot to apply new credentials (same pattern as FACTORY_RESET)
    delay(100);
#if defined(ESP32)
    esp_restart();
#endif
}
```

### 6.5 Flutter-side `DeviceProvider` method

```dart
/// Send WiFi credentials to the device's NVS.
/// Pass null for fields you don't want to change.
Future<bool> sendSetWifi({
  String? ssid,
  String? password,
}) async {
  if (!_transport.isConnected) return false;
  try {
    final pkt = ProtocolService.buildSetWifi(
      ssid: ssid,
      password: password,
    );
    await _writePacket(pkt);
    return true;
  } catch (e) {
    _log('sendSetWifi failed: $e', level: ConsoleLogLevel.error);
    return false;
  }
}
```

### 6.6 Dart-side builder

```dart
/// Build a CMD_SET_WIFI (0x1C) packet to write WiFi creds to NVS.
static Uint8List buildSetWifi({
  String? ssid,
  String? password,
}) {
  final payload = <int>[];
  int fieldMask = 0;

  if (ssid != null) fieldMask |= kSetWifiSsid;
  if (password != null) fieldMask |= kSetWifiPwd;

  payload.add(fieldMask & 0xFF);
  payload.add((fieldMask >> 8) & 0xFF);

  if (ssid != null) {
    final encoded = utf8.encode(ssid);
    final len = encoded.length.clamp(0, kMaxWifiSsid);
    payload.add(len);
    payload.addAll(encoded.take(len));
  }

  if (password != null) {
    final encoded = utf8.encode(password);
    final len = encoded.length.clamp(0, kMaxWifiPwd);
    payload.add(len);
    payload.addAll(encoded.take(len));
  }

  return buildPacket(kCmdSetWifi, payload);
}
```

### 6.7 Password validation (app side)

When the user sets a password (which doubles as the AP password), enforce ≥8 characters:

```dart
if (wifiPassword.isNotEmpty && wifiPassword.length < 8) {
  // Show error: "WiFi password must be at least 8 characters"
}
```

---

## 7. Auth Gate Integration

### 7.1 AP password = connection password

The AP WiFi password is the same as `_nvsPwd` (the connection password from the existing auth system). This means:

- If `_nvsPwd` is empty → AP has **no password** (open network). This is accepted for v1; documented as a first-boot security consideration.
- If `_nvsPwd` is set → AP password = `_nvsPwd` (must be ≥8 chars for WiFi compliance).
- The existing SET_CONF command (0x19) sets `_nvsPwd` — same field is used for AP auth.

### 7.2 Admin gating for SET_WIFI

`RK_CMD_SET_WIFI` (0x1C) writes WiFi credentials to NVS — it must be admin-only:

- **Gate 1** (not authenticated): Block SET_WIFI alongside SET_CONF/FACTORY_RESET.
- **Gate 2** (user-authenticated, not admin): Block SET_WIFI — only PWD_AUTH, GET_CONF, GET_FEATURES pass.

Update `_onPacket()` in `RadioKit.cpp`:
```cpp
// Gate 1 (not authenticated):
if (cmd != RK_CMD_PWD_AUTH && cmd != RK_CMD_GET_CONF && cmd != RK_CMD_GET_FEATURES) { ... }

// Gate 2 (user but not admin):
if (cmd == RK_CMD_SET_CONF || cmd == RK_CMD_FACTORY_RESET || cmd == RK_CMD_SET_WIFI) { ... }
```

### 7.3 User-mode gating

Same dual-auth rules apply:
- **User mode**: May connect via WiFi and control widgets.
- **Admin mode**: Full access (FS, OTA, config, WiFi settings).

WiFi transport does not bypass any auth gates.

---

## 8. Flutter App Changes

### 8.1 New service: `TcpSocketService`

Create `flutter-app/lib/services/tcp_socket_service.dart` implementing `TransportService`:

```dart
class TcpSocketService implements TransportService {
  Socket? _socket;
  String? _host;
  int _port = 5555;
  final List<int> _receiveBuffer = [];
  
  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) async {
    // deviceId format: "ip:port" or just "ip" (port defaults to 5555)
    final parts = deviceId.split(':');
    _host = parts[0];
    if (parts.length > 1) _port = int.parse(parts[1]);
    
    _socket = await Socket.connect(_host!, _port,
        timeout: const Duration(seconds: 5));
    
    _socket!.listen(_onData,
        onError: _onError,
        onDone: _onDone);
  }
  
  @override
  Future<void> writePacket(Uint8List data) async {
    _socket?.add(data);
  }
  
  void _onData(List<int> data) {
    _receiveBuffer.addAll(data);
    while (true) {
      final result = ProtocolService.drainBuffer(_receiveBuffer);
      if (result == null) break;
      
      switch (result.kind) {
        case 'widget':
          onPacketReceived?.call(result.widgetPacket!);
          break;
        case 'fs':
          onFsPacketReceived?.call(result.fsPacket!);
          break;
        case 'ota':
          onOtaPacketReceived?.call(result.otaPacket!);
          break;
      }
    }
  }
  
  void _onError(Object error) {
    onConnectionLost?.call('TCP error: $error');
  }
  
  void _onDone() {
    onConnectionLost?.call('TCP disconnected');
  }
}
```

### 8.2 Connection flow

1. **User selects a WiFi connection** (new option in Pair tab or Models tab).
2. **Discovery**: 
   - The app uses `dart:io` `NetworkInterface` or a mDNS client library to scan for `_radiokit._tcp` services.
   - Manually: user can enter an IP address (with optional port).
3. **Connection**: Creates `TcpSocketService`, calls `deviceProvider.connectToDevice(...)`.
4. **History**: Device is saved as `type: 'wifi'` in HistoryProvider, with the **chip MAC address** as the persistent device ID. The MAC is queried via `CMD_GET_CHIP_INFO` (0x17) on first connection. The last-known IP is saved alongside for reconnection hints.

### 8.3 PairTab changes

Add a "WiFi" tab (or integrate into the existing connection UI) showing:
- Scanned WiFi devices (via mDNS).
- Manual IP entry field (with connect button).

### 8.4 Device info sheet

Add WiFi-specific info to the INFO tab when connected via WiFi:
- IP address
- Signal strength (WiFi.RSSI)
- Mode (AP / STA)
- STA SSID (if in STA mode)

WiFi info is fetched via a new **`CMD_GET_WIFI_INFO` (0x1D)** → **`CMD_WIFI_INFO_DATA` (0x1E)** query/response pair. Payload:
```
[ip0][ip1][ip2][ip3]      // 4 bytes LE
[mode(1)]                  // 0x00 = STA, 0x01 = AP
[ssid_len(1)][ssid...]     // STA SSID (empty if in AP mode with no STA configured)
[rssi(1)]                  // Signal strength in dBm (0 for AP mode)
```

### 8.5 WiFi settings UI

In the settings tab (or device info sheet), add a **WiFi Configuration** section where the user can:
- View current STA SSID (from NVS).
- Set new STA SSID and password.
- See connection status (connected / retrying / AP fallback).

---

## 9. Protocol Constants Summary

### 9.1 Arduino (RadioKitProtocol.h)

| Constant | Value | Description |
|---|---|---|
| `RK_CMD_SET_WIFI` | 0x1C | App → Arduino: write WiFi creds to NVS |
| `RK_SET_WIFI_SSID` | 1 << 0 | SET_WIFI field mask: SSID present |
| `RK_SET_WIFI_PWD` | 1 << 1 | SET_WIFI field mask: Password present |
| `RK_FEATURE_WIFI` | 1 << 4 | Feature bit: WiFi transport active |
| `RK_CMD_GET_WIFI_INFO` | 0x1D | App → Arduino: request WiFi status |
| `RK_CMD_WIFI_INFO_DATA` | 0x1E | Arduino → App: WiFi status payload |

### 9.2 NVS keys (RadioKitNVS.h)

| Key | C++ constant | Max length |
|---|---|---|
| `rk_sta_ssid` | `RK_NVS_KEY_STA_SSID` | 32 |
| `rk_sta_pwd` | `RK_NVS_KEY_STA_PWD` | 64 |

### 9.3 Config limits (RadioKitConfig.h)

| Constant | Value | Description |
|---|---|---|
| `RADIOKIT_MAX_SSID` | 32 | STA SSID max chars |
| `RADIOKIT_MAX_WIFI_PWD` | 64 | STA WiFi password max chars |

### 9.4 Dart (protocol.dart)

| Constant | Value | Description |
|---|---|---|
| `kCmdSetWifi` | 0x1C | SET_WIFI command ID |
| `kSetWifiSsid` | 1 << 0 | Field mask: SSID |
| `kSetWifiPwd` | 1 << 1 | Field mask: Password |
| `kFeatureWiFi` | 1 << 4 | WiFi transport feature bit |
| `kCmdGetWifiInfo` | 0x1D | GET_WIFI_INFO command ID |
| `kCmdWifiInfoData` | 0x1E | WIFI_INFO_DATA response ID |
| `kWifiModeSta` | 0x00 | WiFi status: STA mode |
| `kWifiModeAp` | 0x01 | WiFi status: AP mode |
| `kMaxWifiSsid` | 32 | Max SSID length |
| `kMaxWifiPwd` | 64 | Max WiFi password length |
| `kDefaultWifiPort` | 5555 | Default TCP port |

---

## 10. TCP Server Behaviour Details

### 10.1 Accept loop

```cpp
void RadioKitWiFi::update() {
    // Accept new client (drop previous if any — single connection)
    if (_server.hasClient()) {
        _client.stop();
        _client = _server.available();
        
        // Reset packet parsers to prevent misinterpreting partial
        // data from a previous interrupted connection (same as BLE's
        // _onDisconnect which calls rk_rxReset / rk_fsRxReset / rk_otaRxReset).
        rk_rxReset();
        rk_fsRxReset();
        rk_otaRxReset();
        _lastByteMs = 0;
        _lastPacketMs = 0;
    }
    
    // Read from client
    if (_client && _client.connected()) {
        while (_client.available()) {
            uint8_t byte = _client.read();
            _lastPacketMs = millis();
            
            // Feed into 0x55 parser
            uint8_t cmd; const uint8_t* payload; uint16_t payloadLen;
            if (rk_rxFeedByte(byte, cmd, payload, payloadLen)) {
                if (_packetCb) _packetCb(cmd, payload, payloadLen);
                continue;
            }
            
            // Feed into 0xAA parser
            if (rk_fsRxFeedByte(byte, cmd, payload, payloadLen)) {
                if (_fsCb) _fsCb(cmd, payload, payloadLen);
                continue;
            }
            
            // Feed into 0xBB parser
            if (rk_otaRxFeedByte(byte, cmd, payload, payloadLen)) {
                if (_otaCb) _otaCb(cmd, payload, payloadLen);
            }
        }
    }
    
    // Background STA retry (when in AP mode, only if no client connected)
    // Uses WiFi.mode(WIFI_AP_STA) to enable both AP and STA simultaneously
    // during the retry. Don't disrupt an active AP-mode client.
    if (_apMode && _nvsStaSsid[0] != '\0' && !_client.connected()) {
        unsigned long now = millis();
        if (now - _lastStaRetryMs > 60000) {
            _lastStaRetryMs = now;
            // Switch to dual mode for retry
            WiFi.mode(WIFI_AP_STA);
            if (_connectSta(_nvsStaSsid, _nvsStaPwd)) {
                // Transition from AP to STA:
                // 1. No client to disrupt (guard above ensures this)
                // 2. Stop AP mode
                WiFi.softAPdisconnect(true);
                WiFi.mode(WIFI_STA);
                // 3. Start STA mode TCP server (server IP updated automatically)
                // 4. Restart mDNS with new IP
                MDNS.end();
                MDNS.begin("radiokit");
                MDNS.addService("_radiokit", "_tcp", 5555);
                MDNS.addServiceTxt("_radiokit", "_tcp", "mode", "sta");
                MDNS.addServiceTxt("_radiokit", "_tcp", "ip", WiFi.localIP().toString().c_str());
                _apMode = false;
            } else {
                // Stay in AP mode, switch back to AP-only
                WiFi.mode(WIFI_AP);
            }
        }
    }
}
```

### 10.2 Send packet

```cpp
void RadioKitWiFi::sendPacket(const uint8_t* buf, uint16_t len) {
    if (_client && _client.connected()) {
        _client.write(buf, len);
    }
}
```

### 10.3 Junk recovery

Same pattern as Serial transport: if mid-packet bytes stop arriving for >1000ms, reset all parsers.

```cpp
if (_lastByteMs > 0 && (millis() - _lastByteMs) > 1000) {
    rk_rxReset();
    rk_fsRxReset();
    rk_otaRxReset();
    _lastByteMs = 0;
}
```

---

## 11. Implementation Plan

### Phase 1: Arduino library

1. **RadioKitConfig.h** — Add `RADIOKIT_MAX_SSID`, `RADIOKIT_MAX_WIFI_PWD` limits.
2. **RadioKitProtocol.h** — Add `RK_CMD_SET_WIFI` (0x1C), `RK_SET_WIFI_SSID`, `RK_SET_WIFI_PWD`, `RK_FEATURE_WIFI`.
3. **RadioKitNVS.h** — Add `RK_NVS_KEY_STA_SSID`, `RK_NVS_KEY_STA_PWD`.
4. **RadioKitLib.h** — Add `_nvsStaSsid`, `_nvsStaPwd` buffers to `RadioKitClass`; add `config.sta_ssid` and `config.sta_password` to `RK_Config`; add `startWiFi()` method declaration.
5. **RadioKitTransport.h** — No changes (existing interface works).
6. **RadioKitWiFi.h / RadioKitWiFi.cpp** — New WiFi transport implementation.
7. **RadioKit.cpp** — Add `startWiFi()`; add `_handleSetWifi()`; update `_syncNvsToBuffers()`; update `_handleGetFeatures()`.
8. **Update examples** — Add a WiFi transport example (e.g. `examples/WiFiSwitch/`).

### Phase 2: Flutter app

1. **protocol.dart** — Add `kCmdSetWifi`, `kSetWifiSsid`, `kSetWifiPwd`, `kFeatureWiFi`, `kMaxWifiSsid`, `kMaxWifiPwd`, `kDefaultWifiPort`.
2. **protocol_service.dart** — Add `buildSetWifi()` and `buildGetWifiInfo()` methods; add `parseWifiInfoData()` helper.
3. **transport_service.dart** — No changes (existing interface works).
4. **tcp_socket_service.dart** — New `TcpSocketService` implementing `TransportService`. Add `tcp_socket_service_stub.dart` and `tcp_socket_service_web.dart` stubs for platforms without `dart:io` `Socket`.
5. **device_provider.dart** — Add `sendSetWifi()`; handle WiFi feature bit; optional: detect WiFi transport type.
6. **HistoryProvider / models_tab.dart** — Handle `type: 'wifi'` paired devices.
7. **PairTab** — Add WiFi discovery tab with mDNS scanning + manual IP entry.
8. **Info tab** — Add WiFi status section (IP, mode, signal).

---

## 12. End-to-End Setup Flow (First Boot)

### 12.1 User journey

1. **First boot** — Device NVS is empty (no STA_SSID configured). Device starts in **AP mode**:
   - SSID: `RK_<device-name>` (e.g. `RK_RC_CONTROLLER`)
   - Password: `_nvsPwd` (empty → open network if no connection password set)

2. **User connects phone to AP** — User opens WiFi settings, connects to `RK_RC_CONTROLLER`.

3. **User opens RadioKit app** — App scans for `_radiokit._tcp` services or the user taps "WiFi" in Pair tab. Device is found at `192.168.4.1:5555`.

4. **App connects via TCP** — `TcpSocketService` connects to device. Device info sheet shows "WiFi mode: AP, no STA configured".

5. **User opens WiFi settings in device info** — Enters STA SSID + password (≥8 chars). Taps "SAVE & REBOOT".

6. **App sends SET_WIFI** — `CMD_SET_WIFI` (0x1C) with SSID + password. Device saves to NVS and reboots.

7. **After reboot** — Device reads NVS, connects to STA network. Starts TCP server + mDNS.

8. **App reconnects** — Either via mDNS auto-discovery or user re-enters the IP (now on the LAN).

### 12.2 Re-configuration (changing networks)

- User opens device info → WiFi settings → enters new STA SSID/password → SAVE & REBOOT.
- Device reboots, connects to new network.

## 13. Security Considerations

### 13.1 AP password enforcement (firmware-side)

The app enforces 8-char minimum for WiFi passwords, but the firmware should also enforce this to prevent misconfiguration via alternative tools (e.g. direct serial commands, remote access API).

In `_handleSetConf()`, when a password change is requested:
```cpp
if ((fieldMask & RK_SET_CONF_PWD) && _nvsPwd[0] != '\0' && strlen(_nvsPwd) < 8) {
    // If WiFi transport was started and password is too short, reject
    // (Note: password may also be used by Serial/BLE transports where
    //  length is unrestricted, so only enforce when WiFi is active)
    if (_transport == &RadioKitWiFiInstance) {
        statusMask |= RK_SET_CONF_ERROR;
        // Don't apply the change
        offset += ...; // skip the field
    }
}
```

### 13.2 Empty password → open AP

When `_nvsPwd` is empty (no connection password set), AP mode starts with **no password** (open network). This is accepted for v1 — standard IoT first-boot pattern (ESP32 WiFiConfig, etc.). The open AP is documented as a security consideration for first-boot setup on a trusted physical network. If password protection is required, the user should set a connection password at compile time or immediately after first connection.

## 14. Open Questions (Resolved)

All design questions from the initial spec have been resolved through review:

| # | Topic | Decision |
|---|-------|----------|
| 1 | SET_WIFI auth gating | **Admin-only** — added to gate 2 alongside SET_CONF, FACTORY_RESET |
| 2 | AP SSID length | **Truncate name to 28 chars** — `RK_` + 28 = 32 total |
| 3 | Reboot after SET_WIFI | **Auto-reboot** with 100ms ACK delay (same as FACTORY_RESET) |
| 4 | mDNS | **Include ESPmDNS** on Arduino side; `multicast_dns` package on Flutter side |
| 5 | WiFi.mode() API | **WIFI_AP_STA** during background retry; switch to WIFI_STA after STA connects |
| 6 | Parser reset on new client | **Reset all parsers** on TCP accept (matches BLE disconnect pattern) |
| 7 | Feature bit gating | **Conditional** — only set when `_transport == &RadioKitWiFiInstance` |
| 8 | Persistent device ID | **Chip MAC address** queried via GET_CHIP_INFO on first connect |
| 9 | Open AP security | **Accept open AP for v1** — standard IoT first-boot pattern |
| 10 | WiFi status info | **New CMD_GET_WIFI_INFO (0x1D)** command for IP, mode, SSID, RSSI |
| 11 | First-boot NVS init | **Write WiFi defaults** alongside name/desc/pwd |
| 12 | rk_rxIsActive() optimization | Minor optimization — document as future note |

### 14.1 Future optimizations

- **WiFi scan for AP mode**: When in AP mode, the device could scan for nearby WiFi networks and report them to the app for easier STA configuration. Future enhancement.
- **rk_rxIsActive() optimization**: Skip 0xAA/0xBB parsers while 0x55 parser is mid-frame. Minor CPU savings — low priority.
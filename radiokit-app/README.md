# RadioKit Flutter App

A companion app for the [RadioKit Arduino library](https://github.com/radiokit) that connects to Arduino devices over Bluetooth Low Energy (BLE), receives a UI configuration, and dynamically renders control widgets.

## Features

- **BLE scanning** — discovers nearby Arduino devices advertising the RadioKit service UUID
- **Dynamic UI** — parses CONF_DATA from the Arduino and renders widgets at runtime
- **Real-time polling** — syncs variable values every 100ms via GET_VARS/VAR_DATA
- **User input** — sends SET_INPUT on every widget interaction
- **Connection health** — PING/PONG keepalive every 2 seconds
- **Auto-reconnect** — navigates back to scan screen on disconnection

## Widget Types

| Widget    | Direction | Description                              |
|-----------|-----------|------------------------------------------|
| Button    | Input     | Momentary press — value 1 while held     |
| Switch    | Input     | Toggle ON/OFF                            |
| Slider    | Input     | Linear 0–100 with value label            |
| Joystick  | Input     | 2-axis draggable, springs to center      |
| LED       | Output    | Colour indicator (off/red/green/blue/yellow) |
| Text      | Output    | Read-only 32-byte string display         |

## Protocol

All communication uses the RadioKit binary protocol v1.0 over a BLE UART service:

- **Service UUID:** `0000FFE0-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID:** `0000FFE1-0000-1000-8000-00805F9B34FB`
- **Packet format:** `START(0x55) + LENGTH(2 LE) + CMD(1) + PAYLOAD(N) + CRC16(2 LE)`
- **CRC:** CRC-16/CCITT (poly 0x1021, init 0xFFFF) over CMD + PAYLOAD

See [PROTOCOL.md](../PROTOCOL.md) for the full specification.

## Project Structure

```
lib/
├── main.dart                   # Entry point, orientation lock
├── app.dart                    # MaterialApp + Provider tree
├── theme/
│   └── app_theme.dart          # Dark theme (#1A1A2E palette)
├── models/
│   ├── protocol.dart           # Protocol constants + UUID
│   ├── widget_config.dart      # WidgetConfig + WidgetState models
│   └── device_info.dart        # BLE device model with signal strength
├── services/
│   ├── protocol_service.dart   # CRC-16, packet building/parsing
│   └── ble_service.dart        # BLE scan, connect, notify, write
├── providers/
│   ├── ble_provider.dart       # Scan state + device list
│   └── device_provider.dart    # Connected device, widget state, polling
├── screens/
│   ├── scan_screen.dart        # BLE scanner with device list cards
│   └── control_screen.dart     # Dynamic widget canvas (1000×1000 virtual)
└── widgets/
    ├── button_widget.dart      # Animated momentary button
    ├── switch_widget.dart      # Animated toggle switch
    ├── slider_widget.dart      # Material slider with value display
    ├── joystick_widget.dart    # Custom-painted dual-axis joystick
    ├── led_widget.dart         # Glowing LED indicator
    └── text_widget.dart        # Styled text display
```

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0.0
- Android SDK with API 21+ device / emulator
- iOS 13+ device (BLE scanning does **not** work on simulator)

### Installation

```bash
flutter pub get
```

### Android

The app targets Android API 21+ with BLE permissions declared in `AndroidManifest.xml`:
- `BLUETOOTH` / `BLUETOOTH_ADMIN` (API ≤ 30)
- `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (API 31+)
- `ACCESS_FINE_LOCATION` (required for scanning on API < 31)

### iOS

Add these entries to `ios/Runner/Info.plist` (already present):
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `UIBackgroundModes: bluetooth-central`

Then run:
```bash
cd ios && pod install
```

### Run

```bash
flutter run
```

## Architecture

The app uses clean architecture with Provider for state management:

- **`BleService`** — pure transport layer, no protocol logic
- **`ProtocolService`** — stateless functions for CRC, packet building/parsing
- **`BleProvider`** — ChangeNotifier managing scan lifecycle
- **`DeviceProvider`** — ChangeNotifier managing connection, polling loop, and widget state

Widget rendering scales the 0–1000 virtual coordinate system to the available screen area, maintaining a square aspect ratio with a subtle grid background.

## Colour Palette

| Token       | Hex       | Usage                         |
|-------------|-----------|-------------------------------|
| Background  | `#1A1A2E` | Scaffold background           |
| Surface     | `#16213E` | App bar, canvas background    |
| Primary     | `#0F3460` | Widget card headers, icons    |
| Highlight   | `#E94560` | Active states, buttons, glow  |
| Connected   | `#4CAF50` | Connection status dot         |

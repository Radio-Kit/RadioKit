# Agent Test Manual — Automated MCP Testing

## Overview

This manual describes how to automatically test RadioKit end-to-end using the in-app **Model Context Protocol (MCP)** server on port `7007`.

The previous REST API (`/api/*`) has been **retired**. Automated agents communicate using standard JSON-RPC 2.0 over Server-Sent Events (SSE).

### Architecture

```
┌──────────────┐      HTTP / SSE (port 7007)       ┌──────────────┐   transport   ┌────────────┐
│  Host Agent  │ ────────────────────────────────→ │  RadioKit    │ ←─────────── │  MCU       │
│  (Python/MCP)│    ADB forward / USB tethering    │  Flutter App │   BLE/Serial │  (ESP32)   │
└──────────────┘                                   └──────────────┘               └────────────┘
```

---

## Test Verification Suite

A ready-to-run E2E verification script is located at [`test_mcp_e2e.py`](file:///home/sun/Apps/RCKIT/RadioKit/test_mcp_e2e.py).

### Running Against Android Device

1. Connect phone via USB with ADB enabled.
2. Setup ADB forward:
   ```bash
   adb forward tcp:7007 tcp:7007
   ```
3. Run test script:
   ```bash
   python3 test_mcp_e2e.py http://127.0.0.1:7007
   ```

### Running Over USB Tethering

1. Enable USB Tethering on the phone.
2. Obtain phone IP (e.g. `192.168.153.123`).
3. Run test script directly:
   ```bash
   python3 test_mcp_e2e.py http://192.168.153.123:7007
   ```

---

## Test Steps Executed

1. **SSE Handshake**: Connects to `GET /sse`, extracts `sessionId` from `event: endpoint`.
2. **MCP Initialize**: Calls `initialize` and verifies server identification (`radiokit-app v2.2.0`).
3. **Tool Discovery**: Calls `tools/list` and verifies all 68 tools across 12 functional categories are registered with complete schemas.
4. **Resource Discovery**: Calls `resources/list` and checks for all 13 dynamic resources (`radiokit://console`, `radiokit://widgets`, `radiokit://fs`, `radiokit://diagnostics/connection`, `radiokit://packets`, `radiokit://devices`, `radiokit://models`, `radiokit://designs`, `radiokit://session`, `radiokit://app-log`, `radiokit://flasher/log`, `radiokit://docs`).
5. **Tool Execution**: Calls `radiokit_get_connection_diagnostics`, `radiokit_get_packet_log`, `radiokit_get_connection_status`, `radiokit_flasher_scan`, and `radiokit_scan_devices`.
6. **Resource Reading**: Reads `radiokit://docs`, `radiokit://console`, `radiokit://widgets`, and `radiokit://diagnostics/connection`.
7. **Follow Remote**: Verifies UI screen transitions and logging on the phone.

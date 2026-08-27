# Push Config on Connect — Design

## Context

`DeviceProvider.connectToDevice()` currently sleeps a hardcoded 5 seconds after the transport connects, before requesting the config:

```dart
await _transport.connect(...);                       // BLE: connect + MTU + discover + subscribe
await Future.delayed(const Duration(milliseconds: 5000));  // ← dead air
await _requestConfig();                              // GET_CONF → CONF_DATA → connected
unawaited(_requestDeviceInfo());                     // fire-and-forget
unawaited(_requestFeatures());
...
```

The 5s delay (historically 3.5s) is an unmeasured "let BLE settle" guard. The BLE transport's `connect()` already completes MTU negotiation, service discovery, and notify subscription; the firmware is ready as soon as it advertises (BLE init runs in `setup()`, and NimBLE queues incoming writes). Serial/WiFi/Cloud pay the same 5s despite needing no settle time.

The firmware has a per-characteristic `onSubscribe` callback that today only prints to Serial — the natural hook for a proactive push. `onSubscribe` fires in the NimBLE host task, the same context as `onWrite`, which is where `_handleGetConf()` already builds and sends CONF_DATA today (so `_txBuf` usage from this context is an existing, working pattern).

## Goals / Non-Goals

**Goals:**
- Eliminate the fixed startup delay; make config arrive as soon as the transport is ready.
- BLE: device pushes CONF_DATA + VAR_DATA on client subscribe; the app consumes it without a request.
- Non-BLE transports: app requests config immediately (no delay), keeping the existing request/response flow.
- Keep the protocol transport-agnostic: no new commands, no wire-format changes.
- Recover quickly if the push/request is dropped (fast fallback).

**Non-Goals:**
- No backward compatibility with old firmware (per project policy) — but the app keeps a GET_CONF fallback anyway since it costs little.
- Rendering the control UI from a cached saved design before config arrives (separate optimization; the push already reaches the BLE-connect floor).
- Pushing config on WiFi/Cloud connect (no subscribe event there; request path is instant for those transports).

## Decisions

### D1: Firmware pushes CONF_DATA + VAR_DATA on widget-char subscribe

In `RadioKitBLE.cpp`, the widget characteristic's `onSubscribe` callback (fires with `subValue != 0` when the phone enables notifications — which happens after MTU negotiation in the app's connect sequence) invokes a new `RadioKitClass` method that sends CONF_DATA then VAR_DATA.

- The method reuses the existing `_handleGetConf()` / `_handleGetVars()` bodies (build via `_buildConfPayload` / `_buildVarPayload`, frame with `rk_buildPacket`, send via `_sendPacket`). No protocol change.
- Guard: only push when `subValue != 0` (ignore unsubscribes).
- MTU is already negotiated by subscribe time (the app requests MTU before subscribing), so CONF_DATA chunks at the negotiated size. If MTU somehow arrives later, the send path's chunking uses the current `_negotiatedMtu` and remains correct (smaller chunks).

### D2: Push goes through the generic broadcast send path

`_sendPacket` → `_sendToAllTransports` broadcasts to every active transport (BLE, WiFi, Cloud, Serial). This matches how GET_CONF responses behave today and is harmless: other transports receive a redundant-but-idempotent CONF_DATA (the app re-parses and re-renders). Not targetting the push at BLE only keeps the change minimal and transport-consistent.

### D3: App removes the 5s sleep; requests config immediately

Delete `await Future.delayed(const Duration(milliseconds: 5000))` in `connectToDevice()`. The device-info/features/pages requests (already fire-and-forget) now fire ~5s earlier on every transport.

### D4: BLE uses push-first config acquisition

`_requestConfig()` gains a push-first mode for BLE transports:

- Attempt 0 (BLE only): create the config completer and wait a short window (`kPushWaitTimeout = 3s`) without sending GET_CONF. The pushed CONF_DATA completes the completer (existing `_handleConfData` → `_confCompleter.complete()` path).
- On window timeout, fall through to the existing GET_CONF retry loop (send + `kConfTimeout` = 8s, up to 3 attempts).
- Non-BLE transports: unchanged — send GET_CONF immediately (attempt 0 as today).

This avoids a redundant double send (push + GET_CONF response) while keeping a robustness net if the push is lost. `_handleConfData` is idempotent, so a rare overlap is harmless.

### D5: `kConfTimeout` stays 8s

The fast path is the push (BLE) / immediate request (others). The GET_CONF fallback must not false-timeout on large configs streaming over BLE, so the existing 8s timeout is preserved. No change to `kConfTimeout`.

## Risks / Trade-offs

- **Host-task `_txBuf` reuse**: the push builds into `_txBuf` from the NimBLE host task, racing with `loop()`'s use of the same buffer. This is the *existing* context for `_handleGetConf` (invoked from `onWrite`, also host task), so the push introduces no new race class; subscribe fires once per connection and is low-frequency.
- **Double CONF_DATA on fallback**: if the push arrives late and GET_CONF was also sent, the device sends two CONF_DATA. `_handleConfData` is idempotent (re-parse/re-render) — harmless, rare.
- **Broadcast echo on other transports**: the push reaches any other active transport. Matches today's response behavior; redundant, idempotent.
- **Old firmware without the push**: BLE attempt 0 times out at 3s, then GET_CONF recovers — the app still connects, just 3s slower than push-capable firmware. Acceptable (and no-backward-compat policy means we don't need to optimize for it).
- **On-device timing variance**: subscribe→push delivery depends on BLE stack timing; the 3s window covers chunked transfer of large configs (several KB at ~5-7ms conn intervals).

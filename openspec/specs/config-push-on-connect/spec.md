# config-push-on-connect Specification

## Purpose

Eliminate the fixed startup delay after connection so the device config becomes available as soon as the transport is ready: the device pushes CONF_DATA/VAR_DATA on BLE client subscribe, and the app consumes pushed config immediately while keeping a fast request fallback.

## Requirements

### Requirement: Firmware pushes config on BLE widget-char subscribe

When a BLE client subscribes to the widget characteristic (notifications enabled), the device SHALL send CONF_DATA followed by VAR_DATA over the existing generic send path, without waiting for a GET_CONF/GET_VARS request.

#### Scenario: Phone subscribes to the widget characteristic
- **WHEN** a BLE client enables notifications on the widget characteristic (`onSubscribe` with `subValue != 0`)
- **THEN** the device builds and sends a CONF_DATA packet (same payload as a GET_CONF response) followed by a VAR_DATA packet

#### Scenario: Client unsubscribes or re-subscribes
- **WHEN** the client disables notifications (`subValue == 0`)
- **THEN** the device does not push config; a later re-subscribe pushes again

#### Scenario: Multiple transports active
- **WHEN** the device has other transports active (Serial/WiFi/Cloud) and a BLE client subscribes
- **THEN** the push travels through the standard broadcast send path; the other transports receive a redundant but valid CONF_DATA (same as today's GET_CONF response behavior)

### Requirement: App acquires config without a fixed startup delay

The app SHALL NOT wait a fixed sleep after transport connect before requesting or receiving config. Non-BLE transports SHALL send GET_CONF immediately after connect; BLE SHALL wait a short window (500ms) for the device push and immediately fall back to sending GET_CONF if the push does not arrive within that window.

#### Scenario: Serial/WiFi/Cloud connection
- **WHEN** the app connects via Serial, WiFi, or Cloud
- **THEN** the app sends GET_CONF immediately after connect (no fixed delay) and marks the connection connected when CONF_DATA arrives

#### Scenario: BLE connection with push-capable firmware
- **WHEN** the app connects via BLE and the device pushes CONF_DATA on subscribe
- **THEN** the app consumes the pushed CONF_DATA without sending GET_CONF, within a 500ms wait window

#### Scenario: BLE connection where the push does not arrive
- **WHEN** the 500ms BLE wait window expires without CONF_DATA
- **THEN** the app sends GET_CONF immediately and retries with the existing timeout/retry loop

#### Scenario: Config content equivalence
- **WHEN** the app receives CONF_DATA from a push versus from a GET_CONF response
- **THEN** the parsed config, connection state transition, and downstream rendering are identical (push is indistinguishable from a response)

### Requirement: Fast recovery from a dropped request

A dropped first GET_CONF (or missed push) SHALL not cost the full legacy timeout: the BLE push window provides the fast path, and GET_CONF retries use the existing timeout semantics.

#### Scenario: First GET_CONF dropped on a non-BLE transport
- **WHEN** the first GET_CONF is not answered within the timeout
- **THEN** the existing retry loop re-sends GET_CONF (unchanged behavior, now reached ~5s earlier than before)

import 'package:flutter/material.dart';

/// Structured definition for a contextual help topic.
class HelpTopic {
  final String id;
  final String title;
  final String summary;
  final String explanation;
  final String? hardwareTip;
  final IconData icon;

  const HelpTopic({
    required this.id,
    required this.title,
    required this.summary,
    required this.explanation,
    this.hardwareTip,
    this.icon = Icons.help_outline_rounded,
  });
}

/// Static registry of contextual help topics used across RadioKit.
class HelpTopics {
  static const baudRate = HelpTopic(
    id: 'baud_rate',
    title: 'Serial Baud Rate',
    summary: 'Communication speed for flashing firmware and streaming logs.',
    explanation:
        'Standard ESP32 flashing typically runs at 921,600 baud for fast uploads. '
        'For older USB-to-UART bridges or long cables with electrical noise, '
        'dropping down to 115,200 or 460,800 baud improves reliability.',
    hardwareTip:
        'If flashing fails with CRC or timeout errors, reduce the baud rate to 115,200.',
    icon: Icons.speed_rounded,
  );

  static const cdcTouch = HelpTopic(
    id: 'cdc_touch',
    title: '1200-Baud CDC Auto-Reset',
    summary: 'Software trigger to put native USB ESP32 chips into download mode.',
    explanation:
        'Chips with native USB (ESP32-S3, ESP32-C3/C6) do not have external '
        'dual-transistor auto-reset circuits. Opening the serial port at 1200 baud '
        'and toggling DTR/RTS signals the ROM bootloader to enter download mode without '
        'physically pressing buttons.',
    hardwareTip:
        'If auto-reset fails, manually hold the BOOT button, tap RESET, then release BOOT.',
    icon: Icons.touch_app_rounded,
  );

  static const littlefs = HelpTopic(
    id: 'littlefs',
    title: 'LittleFS Filesystem',
    summary: 'On-chip flash storage partition for widget configs and assets.',
    explanation:
        'RadioKit stores persistent configuration (/config.json), layouts, and UI assets '
        'in a dedicated LittleFS partition on the ESP32. On first boot, the firmware self-initializes '
        'and formats this partition if not present.',
    hardwareTip:
        'Modifying /config.json via the Filesystem Explorer changes widget bindings live on the device.',
    icon: Icons.folder_special_rounded,
  );

  static const transports = HelpTopic(
    id: 'transports',
    title: 'RadioKit Transports',
    summary: 'Protocols used to link the Flutter companion app to microcontrollers.',
    explanation:
        'RadioKit supports 4 simultaneous transport layers:\n'
        '• BLE (Bluetooth Low Energy): Low-power wireless for mobile and tablets.\n'
        '• USB Serial: Fast, wired connection ideal for desktop testing and flashing.\n'
        '• WiFi / mDNS: High-bandwidth LAN discovery without cables.\n'
        '• Cloud Relay: Secure remote access over WebSockets using end-to-end encryption.',
    hardwareTip:
        'On mobile, ensure Bluetooth and Location permissions are granted to discover BLE peripherals.',
    icon: Icons.hub_rounded,
  );

  static const ed25519Pairing = HelpTopic(
    id: 'ed25519_pairing',
    title: 'Device Pairing & Identity',
    summary: 'Cryptographic device authentication using Ed25519 keys.',
    explanation:
        'Each RadioKit node generates an Ed25519 public key. Pairing verifies '
        'the node identity so only authorized apps can control outputs, change pins, or '
        'update onboard firmware.',
    hardwareTip:
        'Scan the QR code printed by the microcontroller serial console on first boot to pair instantly.',
    icon: Icons.verified_user_rounded,
  );

  static const bootloaderMode = HelpTopic(
    id: 'bootloader_mode',
    title: 'ESP32 Bootloader Mode',
    summary: 'Hardware state enabling ROM firmware flashing.',
    explanation:
        'To write new firmware, the ESP32 microcontroller must boot with GPIO0 pulled LOW. '
        'Most development boards handle this automatically via DTR/RTS serial control lines.',
    hardwareTip:
        'Manual Sequence: 1. Press and hold BOOT (GPIO0). 2. Press and release EN/RST. 3. Release BOOT.',
    icon: Icons.memory_rounded,
  );

  static const designerPlayMode = HelpTopic(
    id: 'designer_play_mode',
    title: 'Designer Play Mode',
    summary: 'Simulate live widget interaction directly on the canvas.',
    explanation:
        'Toggle Play Mode in the Designer to test buttons, sliders, gauges, and page switches '
        'without compiling or uploading C++ code to a physical board. Switch back to Edit Mode '
        'to resize, drag, or reconfigure properties.',
    hardwareTip:
        'Play Mode uses simulated local state so you can verify UI ergonomics immediately.',
    icon: Icons.play_circle_outline_rounded,
  );

  static const designerCodegen = HelpTopic(
    id: 'designer_codegen',
    title: 'C++ Header & Codegen',
    summary: 'Export visual designs directly as Arduino C++ code.',
    explanation:
        'RadioKit translates visual layouts into a compact `RADIOKIT.h` header file or JSON configuration. '
        'The generated code instantiates your widgets and registers variable bindings automatically.',
    hardwareTip:
        'Drop the exported `RADIOKIT.h` into your Arduino sketch directory alongside `#include "RADIOKIT.h"`.',
    icon: Icons.code_rounded,
  );
}

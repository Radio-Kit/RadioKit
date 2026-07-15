# RadioKit Agent Skills

These skills are for agents building firmware with the RadioKit Arduino library, and for agents using the Remote Access API to control devices autonomously.

## Firmware Skills

| Skill | Description |
|-------|-------------|
| [radiokit-firmware](radiokit-firmware/SKILL.md) | Complete firmware development guide: setup, config, loop pattern, API reference |
| [radiokit-widgets](radiokit-widgets/SKILL.md) | All widget types: constructors, rk fields, input/output patterns, common recipes |
| [radiokit-transports](radiokit-transports/SKILL.md) | BLE, Serial, WiFi, Cloud transport setup and configuration |
| [radiokit-filesystem](radiokit-filesystem/SKILL.md) | LittleFS filesystem: mounting, file operations, data logging, config persistence |
| [radiokit-ota](radiokit-ota/SKILL.md) | Over-the-air firmware updates: setup, protocol, partition tables |

## Remote Access Skills

| Skill | Description |
|-------|-------------|
| [radiokit-remote](radiokit-remote/SKILL.md) | REST API for remote device control: connect, filesystem, OTA, widgets, console, autonomous debugging |

## Quick Start

**Building firmware**: Start with `radiokit-firmware`, then reference `radiokit-widgets` for widget details.

**Remote device control**: Start with `radiokit-remote` for the full API reference and autonomous debugging patterns.

## Supported Platforms

| Platform | BLE | Serial | WiFi | Cloud | OTA | FS |
|----------|-----|--------|------|-------|-----|-----|
| ESP32 | Yes | Yes | Yes | Yes | Yes | Yes |
| STM32 | No | Yes | No | No | No | No |
| RP2040 | No | Yes | Pico W | Pico W | No | No |

/*__RADIOKIT_Designer_Config__
{
  "version": 1,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1779879673081
  },
  "config": {
    "name": "WiFi_Cloud_Switch",
    "description": "BLE + WiFi + Cloud demo",
    "type": "IOT",
    "transport": "BLE",
    "theme": "RK_DEFAULT",
    "password": ""
  },
  "canvas": {
    "size": [200, 100],
    "grid": "none",
    "skin": "dragon"
  },
  "widgets": [
    {
      "type": "switch",
      "name": "slide_switch_1",
      "label": { "text": "slide_switch_1", "show": false },
      "position": [135, 71, 0],
      "size": [null, 31],
      "haptic": true,
      "variant": "slideSwitch",
      "properties": {
        "onText": "ON",
        "offText": "OFF",
        "autoCenter": [null, "smooth", 300]
      }
    },
    {
      "type": "led",
      "name": "led_1",
      "label": { "text": "led_1", "show": false },
      "position": [115, 29, 0],
      "size": [null, 28],
      "haptic": true,
      "properties": {
        "state": "off",
        "shape": "circle",
        "color": 65280,
        "timing": 500,
        "autoCenter": [null, "smooth", 300]
      }
    }
  ]
}
RADIOKIT_Designer_Config__*/
//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_RockerSwitch slide_switch_1({
    .x = 135, .y = 71,
    .height = 31, .width = 0,
    .rotation = 0
});  // switch: pos=(135,71) size=?x31

RK_LED led_1({
    .x = 115, .y = 29,
    .height = 28, .width = 0,
    .rotation = 0
});  // led: pos=(115,29) size=?x28

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name          = "WiFi_Cloud_Switch";
  RadioKit.config.type          = "IOT";
  RadioKit.config.theme         = RK_DEFAULT;
  RadioKit.config.baudrate      = 1000000;

  // ── Cloud relay compile-time defaults ──────────────────
  // These are written to NVS on first boot. The user can
  // override them via the app's WiFi settings UI at runtime.
  // To use the cloud relay:
  //   1. Set cloud_url to your relay server address
  //   2. Set cloud_account to your account identifier
  // The relay is optional — WiFi transport works without it.
  RadioKit.config.cloud_url     = "";      // e.g. "wss://relay.example.com:443"
  RadioKit.config.cloud_account = "";      // e.g. "my_account"

  // ── STA WiFi compile-time defaults (optional) ──────────
  // If set, the device will try to join this network on boot.
  // If empty, the device starts in AP mode (SSID: RK_WiFi_Cloud_Switch).
  RadioKit.config.sta_ssid      = "Leap";       // e.g. "MyHomeNetwork"
  RadioKit.config.sta_password  = "awsedrft";    // e.g. "MyPassword"

  led_1.setColor(0x00ff00);

  RadioKit.begin();

  // ── Start ALL transports ──────────────────────────────
  // BLE: local control via the RadioKit app
  RadioKit.startBLE(RadioKit.config.name);

  // WiFi: local WebSocket server on port 5555
  // Requires -D RADIOKIT_ENABLE_WIFI in platformio.ini build_flags
  RadioKit.startWiFi();

  // Cloud: outbound relay connection (requires WiFi)
  // This is a no-op if cloud_url is empty.
  // RadioKit.startCloud();  // Disabled for local-only WiFi testing
}

#endif // RADIOKIT_UI_H

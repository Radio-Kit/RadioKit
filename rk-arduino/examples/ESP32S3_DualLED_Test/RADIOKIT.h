/*__RADIOKIT_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "ESP32-S3 Dual LED",
    "description": "ESP32-S3 Dual LED Controller (GPIO 38 & 39)",
    "theme": "dragon",
    "transports": {
      "ble": { "enabled": true },
      "wifi": { "enabled": false }
    }
  },
  "canvas": {
    "size": [200, 100]
  },
  "widgets": [
    {
      "id": "btn_led1",
      "type": "button",
      "variant": "toggle",
      "position": [20, 20, 0],
      "size": [50, 25],
      "label": { "text": "LED 1 (GPIO 38)", "show": true }
    },
    {
      "id": "btn_led2",
      "type": "button",
      "variant": "toggle",
      "position": [90, 20, 0],
      "size": [50, 25],
      "label": { "text": "LED 2 (GPIO 39)", "show": true }
    }
  ]
}
RADIOKIT_Designer_Config__*/

#ifndef RADIOKIT_HEADER_H
#define RADIOKIT_HEADER_H

#define ENABLE_RK_SERIAL
#define ENABLE_RK_BLE

#include <RadioKitLib.h>

RK_ToggleButton btn_led1(20, 20, 25, 50);
RK_ToggleButton btn_led2(90, 20, 25, 50);

inline void initRadioKit() {
    btn_led1.rk.label = "LED 1 (GPIO 38)";
    btn_led1.rk.onText = "ON";
    btn_led1.rk.offText = "OFF";

    btn_led2.rk.label = "LED 2 (GPIO 39)";
    btn_led2.rk.onText = "ON";
    btn_led2.rk.offText = "OFF";
}

#endif // RADIOKIT_HEADER_H

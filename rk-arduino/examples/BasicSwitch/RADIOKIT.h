/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1779879673081
  },
  "config": {
    "name": "Basic_Switch",
    "description": "",
    "type": "IOT",
    "transports": {
      "ble": { "enabled": true },
      "wifi": { "enabled": false, "ssid": "", "pass": "" },
      "cloud": { "enabled": false, "account": "", "relay": "" }
    },
    "theme": "dragon",
    "password": ""
  },
  "canvas": {
    "size": [
      200,
      100
    ],
    "grid": "none",
    "skin": "dragon"
  },
  "pages": [
    {
      "name": "Controls",
      "orientation": "landscape",
      "widgets": [
    {
      "type": "switch",
      "name": "slide_switch_1",
      "label": {
        "text": "slide_switch_1",
        "show": false
      },
      "position": [
        135,
        71,
        0
      ],
      "size": [
        null,
        31
      ],
      "haptic": true,
      "variant": "slideSwitch",
      "properties": {
        "onText": "ON",
        "offText": "OFF",
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    },
    {
      "type": "button",
      "name": "button_1",
      "label": {
        "text": "button_1",
        "show": false
      },
      "position": [
        155,
        28,
        0
      ],
      "size": [
        null,
        34
      ],
      "haptic": true,
      "properties": {
        "variant": "push",
        "onText": "ON",
        "offText": "OFF",
        "onIcon": null,
        "offIcon": null,
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    },
    {
      "type": "led",
      "name": "led_2",
      "label": {
        "text": "led_2",
        "show": false
      },
      "position": [
        48,
        49,
        0
      ],
      "size": [
        null,
        32
      ],
      "haptic": true,
      "properties": {
        "state": "off",
        "shape": "circle",
        "color": 65280,
        "timing": 500,
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    },
    {
      "type": "led",
      "name": "led_1",
      "label": {
        "text": "led_1",
        "show": false
      },
      "position": [
        115,
        29,
        0
      ],
      "size": [
        null,
        28
      ],
      "haptic": true,
      "properties": {
        "state": "off",
        "shape": "circle",
        "color": 65280,
        "timing": 500,
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    }
  ]
    }
  ]
}
RADIOKIT_Designer_Config__*/
//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#define RK_ENABLE_BLE
#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_RockerSwitch slide_switch_1(135, 71, 31);  // switch: pos=(135,71) size=?x31 label="slide_switch_1"
RK_PushButton button_1(155, 28, 34);          // button: pos=(155,28) size=?x34 label="button_1"
RK_LED led_2(48, 49, 32);                    // led: pos=(48,49) size=?x32 label="led_2"
RK_LED led_1(115, 29, 28);                   // led: pos=(115,29) size=?x28 label="led_1"

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "Basic_Switch";
  RadioKit.config.type        = "IOT";
  RadioKit.config.theme       = "dragon";
  RadioKit.config.baudrate    = 1000000;

  button_1.rk.onText  = "ON";
  button_1.rk.offText = "OFF";
  led_2.rk.color      = 0x00ff00;
  led_1.rk.color      = 0x00ff00;

  RadioKit.begin();

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
}

#endif // RADIOKIT_UI_H


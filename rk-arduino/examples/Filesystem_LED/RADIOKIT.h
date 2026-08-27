/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1780753772137
  },
  "config": {
    "name": "FS LED",
    "description": "Bulk filesystem + BLE LED switch",
    "type": "IOT",
    "transports": {
      "ble": { "enabled": true },
      "wifi": { "enabled": false, "ssid": "", "pass": "" },
      "cloud": { "enabled": false, "account": "", "relay": "" }
    },
    "theme": "dragon",
    "password": "1234"
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
      "name": "Main",
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
          101,
          46,
          0
        ],
        "size": [
          null,
          20
        ],
        "haptic": true,
        "variant": "slideSwitch",
        "properties": {
          "onText": "ON",
          "offText": "OFF"
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

#define RK_ENABLE_FS
#define RK_ENABLE_BLE

#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_RockerSwitch slide_switch_1(101, 46, 20);  // switch: pos=(101,46) size=?x20

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "FS LED";
  RadioKit.config.description = "Bulk filesystem + BLE LED switch";
  RadioKit.config.type        = "IOT";
  RadioKit.config.theme       = "dragon";
  RadioKit.config.password    = "1234";

  slide_switch_1.setLabelHidden(true);

  RadioKit.begin();

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
}

#endif // RADIOKIT_UI_H

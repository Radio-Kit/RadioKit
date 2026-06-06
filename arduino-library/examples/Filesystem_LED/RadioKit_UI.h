/*__RadioKit_UI_Designer_Config__
{
  "version": 1,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1780753772137
  },
  "config": {
    "name": "FS LED",
    "description": "Bulk filesystem + BLE LED switch",
    "type": "IOT",
    "transport": "BLE",
    "theme": "RK_DEFAULT",
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
RadioKit_UI_Designer_Config__*/
//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKit.h>

// ─── Widget Declarations ───
RK_RockerSwitch slide_switch_1({
    .x = 101, .y = 46,
    .height = 20, .width = 0,
    .rotation = 0
});  // switch: pos=(101,46) size=?x20 label="slide_switch_1"

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "FS LED";
  RadioKit.config.description = "Bulk filesystem + BLE LED switch";
  RadioKit.config.type        = "IOT";
  RadioKit.config.theme       = RK_DEFAULT;
  RadioKit.config.password    = "1234";

  slide_switch_1.setLabelHidden(true);

  RadioKit.begin();
  RadioKit.startBLE();
}

#endif // RADIOKIT_UI_H


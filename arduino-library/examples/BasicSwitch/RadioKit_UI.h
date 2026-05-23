/*__RadioKit_UI_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "Basic_Switch",
    "description": "",
    "type": "IOT",
    "transport": "Serial",
    "theme": "RK_DEFAULT",
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
  "widgets": [
    {
      "type": "switch",
      "name": "slide_switch_1",
      "label": {
        "text": "slide_switch_1",
        "show": false
      },
      "position": [
        102,
        52,
        0
      ],
      "size": [
        null,
        40
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
    .x = 102, .y = 52,
    .height = 40, .width = 0,
    .rotation = 0
});  // switch: pos=(102,52) size=?x40 label="slide_switch_1"

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "Basic_Switch";
  RadioKit.config.type        = "IOT";
  RadioKit.config.theme       = RK_DEFAULT;

  RadioKit.begin();
  RadioKit.startSerial(Serial);
}

#endif // RADIOKIT_UI_H


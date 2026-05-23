/*__RadioKit_UI_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "ServoControl",
    "description": "SliderServo — servo control via slider",
    "type": "Locomotive",
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
      "type": "slider",
      "name": "servoSlider",
      "label": { "text": "Angle", "show": true },
      "position": [100, 50, 0],
      "size": [80, 12]
    },
    {
      "type": "led",
      "name": "zoneLED",
      "label": { "text": "Zone", "show": true },
      "position": [20, 20, 0],
      "size": [null, 14]
    },
    {
      "type": "text",
      "name": "angleText",
      "label": { "text": "Deg", "show": true },
      "position": [20, 80, 0],
      "size": [60, 10]
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
RK_Slider servoSlider({
    .x = 100, .y = 50,
    .height = 12, .width = 80,
    .label = "Angle"
});

RK_LED zoneLED({
    .x = 20, .y = 20,
    .height = 14,
    .label = "Zone"
});

RK_Text angleText({
    .x = 20, .y = 80,
    .height = 10, .width = 60,
    .label = "Deg"
});

// ─── Config Init ───
static inline void initRadioKit()
{
    RadioKit.config.name        = "ServoControl";
    RadioKit.config.description = "SliderServo — servo control via slider";
    RadioKit.config.theme       = RK_DEFAULT;
    RadioKit.config.password    = "";

    RadioKit.begin();
    RadioKit.startBLE(RadioKit.config.name);
}

#endif // RADIOKIT_UI_H

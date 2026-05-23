/*__RadioKit_UI_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "RobotDrive",
    "description": "JoystickMotor — dual motor control with joystick",
    "type": "Robot",
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
      "type": "joystick",
      "name": "drive",
      "label": { "text": "Drive", "show": true },
      "position": [160, 50, 0],
      "size": [null, 60]
    },
    {
      "type": "pushButton",
      "name": "eStop",
      "label": { "text": "E-Stop", "show": true },
      "position": [20, 50, 0],
      "size": [null, 24]
    },
    {
      "type": "led",
      "name": "dirLED",
      "label": { "text": "", "show": false },
      "position": [20, 20, 0],
      "size": [null, 14]
    },
    {
      "type": "text",
      "name": "speedText",
      "label": { "text": "Speed", "show": true },
      "position": [100, 20, 0],
      "size": [null, 10]
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
RK_Joystick drive({
    .x = 160, .y = 50,
    .height = 60,
    .label = "Drive"
});

RK_PushButton eStop({
    .x = 20, .y = 50,
    .height = 24,
    .label = "E-Stop"
});

RK_LED dirLED({
    .x = 20, .y = 20,
    .height = 14
});

RK_Text speedText({
    .x = 100, .y = 20,
    .height = 10,
    .label = "Speed"
});

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "RobotDrive";
  RadioKit.config.description = "JoystickMotor — dual motor control";
  RadioKit.config.theme       = RK_DEFAULT;

  RadioKit.begin();
  RadioKit.startBLE(RadioKit.config.name);
}

#endif // RADIOKIT_UI_H

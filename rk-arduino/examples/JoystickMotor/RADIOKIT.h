/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "config": {
    "name": "RobotDrive",
    "description": "JoystickMotor — dual motor control with joystick",
    "type": "Robot",
    "transports": {
      "ble": { "enabled": true },
      "wifi": { "enabled": false, "ssid": "", "pass": "" },
      "cloud": { "enabled": false, "account": "", "relay": "" }
    },
    "theme": "dragon",
    "password": ""
  },
  "canvas": {
    "size": [200, 100],
    "grid": "none",
    "skin": "dragon"
  },
  "pages": [
    {
      "name": "Main",
      "orientation": "landscape",
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
RK_Joystick drive(160, 50, 60);
RK_PushButton eStop(20, 50, 24);
RK_LED dirLED(20, 20, 14);
RK_Text speedText(100, 20, 10);

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "RobotDrive";
  RadioKit.config.description = "JoystickMotor — dual motor control";
  RadioKit.config.theme       = "dragon";

  drive.rk.label = "Drive";
  eStop.rk.onText = "STOP";
  eStop.rk.offText = "ARMED";
  eStop.rk.label = "E-Stop";
  speedText.rk.label = "Speed";

  RadioKit.begin();

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
}

#endif // RADIOKIT_UI_H

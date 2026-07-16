/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "config": {
    "name": "RC Truck",
    "description": "Advanced RC Truck Controller",
    "type": "Vehicle",
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
    "skin": "cyberpunk"
  },
  "pages": [
    {
      "name": "Main",
      "orientation": "landscape",
      "widgets": [
      {
        "type": "slider",
        "variant": "gasPedal",
        "name": "gasPedal",
        "label": { "text": "Gas Pedal", "show": true },
        "position": [15, 60, -90],
        "size": [null, 12],
        "autoCenter": ["min", "smooth", 300],
        "properties": { "min": -100, "max": 100 }
      },
      {
        "type": "knob",
        "variant": "steeringWheel",
        "name": "steeringWheel",
        "label": { "text": "Steering", "show": true },
        "position": [85, 60, 0],
        "size": [null, 30],
        "autoCenter": ["center", "smooth", 500],
        "properties": { "startAngle": -150, "endAngle": 150 }
      },
      {
        "type": "multiButton",
        "name": "driveMode",
        "label": { "text": "Gear", "show": true },
        "position": [50, 85, 0],
        "size": [null, 10],
        "variant": "multiButton",
        "properties": {
          "items": [
            { "onLabel": "D", "onIcon": "drive_eta" },
            { "onLabel": "P", "onIcon": "local_parking" },
            { "onLabel": "R", "onIcon": "settings_backup_restore" }
          ]
        }
      },
      {
        "type": "multiSelect",
        "name": "lights",
        "label": { "text": "Truck Lights", "show": true },
        "position": [50, 35, 0],
        "size": [null, 10],
        "variant": "multiSelect",
        "properties": {
          "items": [
            { "onLabel": "Head", "onIcon": "lightbulb" },
            { "onLabel": "Fog", "onIcon": "cloud" },
            { "onLabel": "Hazard", "onIcon": "warning" },
            { "onLabel": "Cabin", "onIcon": "home" }
          ]
        }
      },
      {
        "type": "text",
        "name": "truckStatus",
        "label": { "text": "Truck Status", "show": true },
        "position": [50, 10, 0],
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
RK_GasPedal         gasPedal(15, 60, 12, 0, -90);
RK_Knob             steeringWheel(85, 60, 30);
RK_MultipleButton   driveMode(50, 85, 10);
RK_MultipleSelect   lights(50, 35, 10);
RK_Text             truckStatus(50, 10, 10);

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "RC Truck";
  RadioKit.config.description = "Advanced RC Truck Controller";
  RadioKit.config.theme       = "dragon";
  RadioKit.config.orientation = RK_LANDSCAPE;

  // Post-construction widget configuration
  gasPedal.rk.label           = "Gas Pedal";
  steeringWheel.rk.label      = "Steering";
  steeringWheel.rk.startAngle = -150;
  steeringWheel.rk.endAngle   = 150;
  steeringWheel.rk.centering  = RK_SPRING_CENTER;
  steeringWheel.rk.variant    = 1;

  driveMode.rk.label = "Gear";
  driveMode.rk.items[0] = {"D", "drive_eta", 0};
  driveMode.rk.items[1] = {"P", "local_parking", 1};
  driveMode.rk.items[2] = {"R", "settings_backup_restore", 2};
  driveMode.rk.itemCount = 3;

  lights.rk.label = "Truck Lights";
  lights.rk.items[0] = {"Head", "lightbulb", 0};
  lights.rk.items[1] = {"Fog", "cloud", 1};
  lights.rk.items[2] = {"Hazard", "warning", 2};
  lights.rk.items[3] = {"Cabin", "home", 3};
  lights.rk.itemCount = 4;

  truckStatus.rk.label = "Truck Status";

  RadioKit.begin();

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
}

#endif // RADIOKIT_UI_H

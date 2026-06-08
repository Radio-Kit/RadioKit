/*__RADIOKIT_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "RC Truck",
    "description": "Advanced RC Truck Controller",
    "type": "Vehicle",
    "transport": "BLE",
    "theme": "RK_CYBERPUNK",
    "password": ""
  },
  "canvas": {
    "size": [200, 100],
    "grid": "none",
    "skin": "cyberpunk"
  },
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
RADIOKIT_Designer_Config__*/

//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_GasPedal gasPedal({
    .x = 15, .y = 60,
    .height = 12,
    .rotation = -90,
    .label = "Gas Pedal",
    .value = -100
});

RK_Knob steeringWheel({
    .x = 85, .y = 60,
    .height = 30,
    .startAngle = -150,
    .endAngle = 150,
    .centering = RK_SPRING_CENTER,
    .variant = 1,
    .label = "Steering",
    .value = 0
});

RK_MultipleButton driveMode({
    .x = 50, .y = 85,
    .items = {
        { .label = "D", .icon = "drive_eta" },
        { .label = "P", .icon = "local_parking" },
        { .label = "R", .icon = "settings_backup_restore" }
    },
    .label = "Gear"
});

RK_MultipleSelect lights({
    .x = 50, .y = 35,
    .items = {
        { .label = "Head", .icon = "lightbulb" },
        { .label = "Fog", .icon = "cloud" },
        { .label = "Hazard", .icon = "warning" },
        { .label = "Cabin", .icon = "home" }
    },
    .label = "Truck Lights"
});

RK_Text truckStatus({
    .x = 50, .y = 10,
    .height = 10,
    .label = "Truck Status"
});

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "RC Truck";
  RadioKit.config.description = "Advanced RC Truck Controller";
  RadioKit.config.theme       = RK_CYBERPUNK;
  RadioKit.config.orientation = RK_LANDSCAPE;

  RadioKit.begin();
  RadioKit.startBLE(RadioKit.config.name);
}

#endif // RADIOKIT_UI_H

/*__RADIOKIT_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "Serial Test v2.0",
    "description": "USB Serial Connection Test Example",
    "type": "IOT",
    "transport": "Serial",
    "theme": "RK_DEFAULT",
    "password": "1234"
  },
  "canvas": {
    "size": [200, 100],
    "grid": "none",
    "skin": "dragon"
  },
  "widgets": [
    {
      "type": "pushButton",
      "name": "btn",
      "label": { "text": "Press", "show": true },
      "position": [20, 60, 0],
      "size": [null, 20],
      "properties": { "icon": "wifi" }
    },
    {
      "type": "toggleButton",
      "name": "sw",
      "label": { "text": "LED", "show": true },
      "position": [20, 80, 0],
      "size": [null, 20]
    },
    {
      "type": "switch",
      "variant": "slideSwitch",
      "name": "slideSw",
      "label": { "text": "Power", "show": true },
      "position": [20, 40, 0],
      "size": [null, 10],
      "properties": { "icon": "power", "onText": "ON", "offText": "OFF" }
    },
    {
      "type": "slider",
      "name": "sld",
      "label": { "text": "Level", "show": true },
      "position": [100, 60, 45],
      "size": [null, 10]
    },
    {
      "type": "knob",
      "name": "pan",
      "label": { "text": "Pan", "show": true },
      "position": [170, 40, 0],
      "size": [null, 40],
      "properties": { "icon": "knob", "centering": "center" }
    },
    {
      "type": "knob",
      "variant": "steeringWheel",
      "name": "steering",
      "label": { "text": "Steer", "show": true },
      "position": [170, 80, 0],
      "size": [null, 40],
      "properties": { "icon": "steering", "centering": "center", "startAngle": -90, "endAngle": 90 }
    },
    {
      "type": "joystick",
      "name": "joy",
      "label": { "text": "Stick", "show": true },
      "position": [160, 70, 0],
      "size": [null, 20]
    },
    {
      "type": "multiButton",
      "name": "mode",
      "label": { "text": "Multiple Button", "show": true },
      "position": [60, 30, 0],
      "size": [null, 10],
      "properties": {
        "items": [
          { "onLabel": "Auto", "onIcon": "cpu" },
          { "onLabel": "Man", "onIcon": "hand" }
        ]
      }
    },
    {
      "type": "multiSelect",
      "name": "opts",
      "label": { "text": "Multiple Select", "show": true },
      "position": [60, 90, 0],
      "size": [null, 10],
      "properties": {
        "items": [
          { "onLabel": "Log", "onIcon": "file-text" },
          { "onLabel": "Mute", "onIcon": "volume-x" }
        ]
      }
    },
    {
      "type": "led",
      "name": "statusLED",
      "label": { "text": "Status", "show": true },
      "position": [20, 20, 0],
      "size": [null, 14]
    },
    {
      "type": "text",
      "name": "uptimeText",
      "label": { "text": "Uptime", "show": true },
      "position": [20, 10, 0],
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
RK_PushButton btn({
    .x = 20, .y = 60, .height = 20,
    .icon = "wifi",
    .label = "Press"
});

RK_ToggleButton sw({
    .x = 20, .y = 80, .height = 20,
    .label = "LED"
});

RK_SlideSwitch slideSw({
    .x = 20, .y = 40, .height = 10,
    .icon = "power",
    .onText = "ON", .offText = "OFF",
    .label = "Power",
    .state = false
});

RK_Slider sld({
    .x = 100, .y = 60, .height = 10,
    .rotation = 45,
    .label = "Level",
    .value = 0
});

RK_Knob pan({
    .x = 170, .y = 40, .height = 40,
    .icon = "knob",
    .centering = RK_SPRING_CENTER,
    .label = "Pan"
});

RK_Knob steering({
    .x = 170, .y = 80, .height = 40,
    .icon = "steering",
    .startAngle = -90, .endAngle = 90,
    .centering = RK_SPRING_CENTER,
    .variant = 1,
    .label = "Steer"
});

RK_Joystick joy({
    .x = 160, .y = 70, .height = 20,
    .label = "Stick"
});

RK_MultipleButton mode({
    .x = 60, .y = 30,
    .items = {
        { .label = "Auto", .icon = "cpu" },
        { .label = "Man", .icon = "hand" }
    },
    .label = "Multiple Button"
});

RK_MultipleSelect opts({
    .x = 60, .y = 90,
    .items = {
        { .label = "Log", .icon = "file-text" },
        { .label = "Mute", .icon = "volume-x" }
    },
    .label = "Multiple Select"
});

RK_LED statusLED({
    .x = 20, .y = 20, .height = 14,
    .label = "Status"
});

RK_Text uptimeText({
    .x = 20, .y = 10,
    .label = "Uptime"
});

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "Serial Test v2.0";
  RadioKit.config.description = "USB Serial Connection Test Example";
  RadioKit.config.theme       = RK_DEFAULT;
  RadioKit.config.password    = "1234";

  RadioKit.begin();
  RadioKit.startSerial(Serial);
}

#endif // RADIOKIT_UI_H

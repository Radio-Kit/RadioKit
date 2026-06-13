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
RK_PushButton       btn(20, 60, 20);
RK_ToggleButton     sw(20, 80, 20);
RK_SlideSwitch      slideSw(20, 40, 10);
RK_Slider           sld(100, 60, 10, 0, 45);
RK_Knob             pan(170, 40, 40);
RK_Knob             steering(170, 80, 40);
RK_Joystick         joy(160, 70, 20);
RK_MultipleButton   mode(60, 30, 10);
RK_MultipleSelect   opts(60, 90, 10);
RK_LED              statusLED(20, 20, 14);
RK_Text             uptimeText(20, 10, 10);

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "Serial Test v2.0";
  RadioKit.config.description = "USB Serial Connection Test Example";
  RadioKit.config.theme       = RK_DEFAULT;
  RadioKit.config.password    = "1234";

  // Post-construction widget configuration
  btn.rk.label         = "Press";
  btn.rk.icon          = "wifi";
  sw.rk.label          = "LED";
  slideSw.rk.icon      = "power";
  slideSw.rk.onText    = "ON";
  slideSw.rk.offText   = "OFF";
  slideSw.rk.label     = "Power";
  sld.rk.label         = "Level";
  pan.rk.icon          = "knob";
  pan.rk.centering     = RK_SPRING_CENTER;
  pan.rk.label         = "Pan";
  steering.rk.icon       = "steering";
  steering.rk.label      = "Steer";
  steering.rk.startAngle = -90;
  steering.rk.endAngle   = 90;
  steering.rk.centering  = RK_SPRING_CENTER;
  steering.rk.variant    = 1;
  joy.rk.label        = "Stick";
  mode.rk.label       = "Multiple Button";
  mode.rk.items[0]    = {"Auto", "cpu", 0};
  mode.rk.items[1]    = {"Man", "hand", 1};
  mode.rk.itemCount   = 2;
  opts.rk.label       = "Multiple Select";
  opts.rk.items[0]    = {"Log", "file-text", 0};
  opts.rk.items[1]    = {"Mute", "volume-x", 1};
  opts.rk.itemCount   = 2;
  statusLED.rk.label  = "Status";
  uptimeText.rk.label = "Uptime";

  RadioKit.begin();
  RadioKit.startSerial(Serial);
}

#endif // RADIOKIT_UI_H

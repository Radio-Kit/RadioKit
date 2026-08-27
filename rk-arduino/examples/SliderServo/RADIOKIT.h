/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "config": {
    "name": "ServoControl",
    "description": "SliderServo — servo control via slider",
    "type": "Locomotive",
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
        "type": "slider",
        "name": "servoSlider",
        "label": { "text": "servoSlider", "show": true },
        "position": [100, 70, 0],
        "size": [147, 26],
        "haptic": true,
        "properties": { "min": -100, "max": 100, "divisions": null, "autoCenter": [null, "smooth", 300] }
      },
      {
        "type": "led",
        "name": "zoneLED",
        "label": { "text": "zoneLED", "show": true },
        "position": [45, 28, 0],
        "size": [null, 22],
        "haptic": true,
        "properties": { "state": "off", "shape": "circle", "color": 65280, "timing": 500, "autoCenter": [null, "smooth", 300] }
      },
      {
        "type": "text",
        "name": "angleText",
        "label": { "text": "angleText", "show": true },
        "position": [139, 28, 0],
        "size": [67, 16],
        "haptic": true,
        "properties": { "text": "Display", "fontSize": 14, "fontFamily": "monospace", "autoCenter": [null, "smooth", 300] }
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
RK_Slider servoSlider(100, 70, 26, 147);  // slider: pos=(100,70) size=147x26 label="servoSlider"
RK_LED   zoneLED(45, 28, 22);             // led: pos=(45,28) size=?x22 label="zoneLED"
RK_Text  angleText(139, 28, 16, 67);      // text: pos=(139,28) size=67x16 label="angleText"

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "ServoControl";
  RadioKit.config.description = "SliderServo — servo control via slider";
  RadioKit.config.theme       = "dragon";
  RadioKit.config.baudrate    = 1000000;

  // Post-construction widget configuration
  servoSlider.rk.label      = "servoSlider";
  zoneLED.rk.label          = "zoneLED";
  zoneLED.rk.color          = 0x00ff00;
  angleText.rk.label        = "angleText";
  angleText.rk.content      = "Display";

  RadioKit.begin();

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();
}

#endif // RADIOKIT_UI_H

/*__RADIOKIT_Designer_Config__
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
    "size": [
      200,
      100
    ],
    "grid": "none",
    "skin": "dragon"
  },
  "widgets": [
    {
      "type": "slider",
      "name": "servoSlider",
      "label": {
        "text": "servoSlider",
        "show": true
      },
      "position": [
        100,
        70,
        0
      ],
      "size": [
        147,
        26
      ],
      "haptic": true,
      "properties": {
        "min": -100,
        "max": 100,
        "divisions": null,
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    },
    {
      "type": "led",
      "name": "zoneLED",
      "label": {
        "text": "zoneLED",
        "show": true
      },
      "position": [
        45,
        28,
        0
      ],
      "size": [
        null,
        22
      ],
      "haptic": true,
      "properties": {
        "state": "off",
        "shape": "circle",
        "color": 65280,
        "timing": 500,
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    },
    {
      "type": "text",
      "name": "angleText",
      "label": {
        "text": "angleText",
        "show": true
      },
      "position": [
        139,
        28,
        0
      ],
      "size": [
        67,
        16
      ],
      "haptic": true,
      "properties": {
        "text": "Display",
        "fontSize": 14,
        "fontFamily": "monospace",
        "autoCenter": [
          null,
          "smooth",
          300
        ]
      }
    }
  ]
}
RADIOKIT_Designer_Config__*/

//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_
//__RadioKit_Generated_Code__
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKitLib.h>

// ─── Widget Declarations ───
RK_Slider servoSlider({
    .x = 100, .y = 70,
    .height = 26, .width = 147,
    .rotation = 0
});  // slider: pos=(100,70) size=147x26 label="servoSlider"

RK_LED zoneLED({
    .x = 45, .y = 28,
    .height = 22, .width = 0,
    .rotation = 0
});  // led: pos=(45,28) size=?x22 label="zoneLED"

RK_Text angleText({
    .x = 139, .y = 28,
    .height = 16, .width = 67
});  // text: pos=(139,28) size=67x16 label="angleText"
<<<<<<< Updated upstream
=======

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "ServoControl";
  RadioKit.config.description = "SliderServo — servo control via slider";
  RadioKit.config.type        = "Locomotive";
  RadioKit.config.theme       = RK_DEFAULT;
  RadioKit.config.baudrate    = 1000000;

  servoSlider.props.centering = RK_SPRING_NONE;
  zoneLED.setColor(0x00ff00);
  angleText.set("Display");

  RadioKit.begin();
  RadioKit.startBLE(RadioKit.config.name);
>>>>>>> Stashed changes

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "ServoControl";
  RadioKit.config.description = "SliderServo — servo control via slider";
  RadioKit.config.type        = "Locomotive";
  RadioKit.config.theme       = RK_DEFAULT;
  RadioKit.config.baudrate    = 1000000;

  servoSlider.props.centering = RK_SPRING_NONE;
  zoneLED.setColor(0x00ff00);
  angleText.set("Display");

  RadioKit.begin();
  RadioKit.startBLE(RadioKit.config.name);
}

#endif // RADIOKIT_UI_H
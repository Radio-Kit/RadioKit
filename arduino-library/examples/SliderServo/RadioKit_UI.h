/*__RadioKit_UI_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "ServoControl",
    "description": "SliderServo — RadioKit widget configuration + transport init.",
    "type": "Locomotive",
    "transport": "BLE",
    "theme": "RK_DEFAULT",
    "password": ""
  },
  "canvas": {
    "size": "200 x 100",
    "grid": "none",
    "skin": "dragon"
  },
  "widgets": [
    {
      "id": "placeholder_slider",
      "type": "slider",
      "x": 100,
      "y": 50,
      "width": 80,
      "height": 12,
      "properties": {
        "rotation": 0,
        "label": "Angle",
        "labelHidden": false,
        "min": 0,
        "max": 100,
        "autoCenter": false,
        "center": 0.5,
        "springBehavior": "smooth",
        "springDuration": 300,
        "divisions": null
      }
    },
    {
      "id": "placeholder_led",
      "type": "led",
      "x": 20,
      "y": 20,
      "height": 14,
      "properties": {
        "rotation": 0,
        "label": "Zone",
        "labelHidden": false,
        "state": "on",
        "shape": "circle",
        "color": 65280,
        "timing": 500
      }
    },
    {
      "id": "placeholder_text",
      "type": "text",
      "x": 20,
      "y": 80,
      "width": 60,
      "height": 10,
      "properties": {
        "rotation": 0,
        "label": "Deg",
        "labelHidden": false,
        "text": "",
        "fontSize": 14,
        "fontFamily": "monospace"
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


static inline void initRadioKit()
{
    RadioKit.config.name        = "ServoControl";
    RadioKit.config.description = "SliderServo — RadioKit widget configuration + transport init.";
    RadioKit.config.theme       = RK_DEFAULT;
    RadioKit.config.password    = "";

    RadioKit.begin();
    RadioKit.startBLE(RadioKit.config.name);

}

#endif // RADIOKIT_UI_H

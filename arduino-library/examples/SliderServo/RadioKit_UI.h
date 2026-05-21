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
      "type": "slider", "id": "servoSlider",
      "x": 100, "y": 50,
      "width": 80, "height": 12,
      "rotation": 0,
      "label": "Angle",
      "centering": "none",
      "detents": 0,
      "value": 0
    },
    {
      "type": "led", "id": "zoneLED",
      "x": 20, "y": 20,
      "width": 0, "height": 14,
      "rotation": 0,
      "label": "Zone",
      "state": "on",
      "shape": "circle",
      "color": 65280,
      "timing": 500
    },
    {
      "type": "text", "id": "angleText",
      "x": 20, "y": 80,
      "width": 0, "height": 10,
      "rotation": 0,
      "label": "Deg",
      "content": ""
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

// ─────────────────────────────────────────────────────────────
//  WIDGET FACTORY FUNCTIONS
// ─────────────────────────────────────────────────────────────

// slider: id=servoSlider  pos=(100,50) size=80x12  label="Angle"
static inline RK_Slider mkServoSlider()
{
    RK_SliderProps p;
    p.x         = 100;
    p.y         = 50;
    p.height    = 12;
    p.width     = 80;
    p.rotation  = 0;
    p.label     = "Angle";
    p.centering = RK_SPRING_NONE;
    p.detents   = 0;
    p.value     = 0;
    return RK_Slider(p);
}
RK_Slider  servoSlider = mkServoSlider();

// led: id=zoneLED  pos=(20,20) size=0x14  label="Zone"
static inline RK_LED mkZoneLED()
{
    RK_LedProps p;
    p.x        = 20;
    p.y        = 20;
    p.height   = 14;
    p.width    = 0;
    p.rotation = 0;
    p.label    = "Zone";
    p.color    = 65280;
    p.state    = true;
    p.shape    = RK_LED_SHAPE_CIRCLE;
    p.ledState = RK_LED_STATE_ON;
    p.timing   = 500;
    return RK_LED(p);
}
RK_LED     zoneLED     = mkZoneLED();

// text: id=angleText  pos=(20,80) size=0xA  label="Deg"
static inline RK_Text mkAngleText()
{
    RK_TextProps p;
    p.x        = 20;
    p.y        = 80;
    p.height   = 10;
    p.width    = 0;
    p.label    = "Deg";
    p.content  = "";
    return RK_Text(p);
}
RK_Text    angleText   = mkAngleText();



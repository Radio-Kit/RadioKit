/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "config": {
    "name": "Serial_Simple",
    "description": "Serial-only example for RP2040 — push button toggles LED",
    "theme": "dragon"
  },
  "canvas": {
    "size": [200, 100]
  },
  "pages": [
    {
      "name": "Main",
      "orientation": "landscape",
      "widgets": [
      {
        "type": "button",
        "name": "button_1",
        "label": { "text": "Toggle LED", "show": true },
        "position": [40, 30, 0],
        "size": [80, 30],
        "haptic": true,
        "properties": {
          "variant": "push",
          "onText": "ON",
          "offText": "OFF"
        }
      },
      {
        "type": "led",
        "name": "led_1",
        "label": { "text": "LED", "show": true },
        "position": [40, 70, 0],
        "size": [40, 20],
        "haptic": true,
        "properties": {
          "color": 65280,
          "shape": "circle"
        }
      }
      ]
    }
  ]
}
RADIOKIT_Designer_Config__*/

#ifndef RADIOKIT_SERIAL_SIMPLE_H
#define RADIOKIT_SERIAL_SIMPLE_H

#include <RadioKitLib.h>

// Widget declarations
RK_PushButton button_1(40, 30, 30);
RK_LED led_1(40, 70, 20);

inline void initRadioKit() {
  button_1.rk.onText = "ON";
  button_1.rk.offText = "OFF";
  led_1.rk.color = 0x00FF00; // Green

  RadioKit.begin();
  RadioKit.startSerial(Serial);
}

#endif // RADIOKIT_SERIAL_SIMPLE_H

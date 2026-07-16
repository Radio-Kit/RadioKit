/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "appdata": {
    "appVersion": "1.0.0",
    "lastEdit": 1784191200000
  },
  "config": {
    "name": "MultiPageController",
    "description": "Multi-page controller with separate Control and Settings pages",
    "type": "IOT",
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
      "name": "Control",
      "orientation": "landscape",
      "widgets": [
        {
          "type": "slider",
          "name": "speed",
          "label": { "text": "Speed", "show": true },
          "position": [50, 50, 0],
          "size": [60, 10],
          "autoCenter": ["center", "smooth", 300],
          "properties": { "min": 0, "max": 100 }
        },
        {
          "type": "button",
          "name": "toggle",
          "label": { "text": "Toggle", "show": true },
          "position": [50, 80, 0],
          "size": [30, 15],
          "haptic": true,
          "properties": { "mode": "toggle" }
        }
      ]
    },
    {
      "name": "Settings",
      "orientation": "landscape",
      "widgets": [
        {
          "type": "text",
          "name": "status",
          "label": { "text": "Status", "show": true },
          "position": [50, 30, 0],
          "size": [80, 15]
        },
        {
          "type": "led",
          "name": "indicator",
          "label": { "text": "Indicator", "show": true },
          "position": [50, 70, 0],
          "size": [null, 20],
          "properties": { "color": "#00FF00" }
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
#define RK_NUM_PAGES 2

#include <RadioKitLib.h>

// ─── Page Names ───
static const char* rk_pageNames[] = { "Control", "Settings" };

// ─── Widget Declarations ───
// Page 0: Control
RK_Slider          speed(50, 50, 60, 10, 0);  // x, y, height, width, rotation
RK_ToggleButton    toggle(50, 80, 15, 30);     // x, y, height, width

// Page 1: Settings
RK_Text            status(50, 30, 15, 80);     // x, y, height, width
RK_LED             indicator(50, 70, 20);      // x, y, height

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "MultiPageController";
  RadioKit.config.description = "Multi-page controller with separate Control and Settings pages";
  RadioKit.config.type        = "IOT";
  RadioKit.config.theme       = "dragon";
  RadioKit.config.orientation = RK_LANDSCAPE;

  // Page 0: Control widgets
  speed.rk.label     = "Speed";
  speed.setPage(0);

  toggle.rk.label    = "Toggle";
  toggle.setPage(0);

  // Page 1: Settings widgets
  status.rk.label    = "Status";
  status.setPage(1);

  indicator.rk.label = "Indicator";
  indicator.setPage(1);

  RadioKit.setNumPages(RK_NUM_PAGES);

  RadioKit.begin();

  RadioKit.startSerial(Serial);
  RadioKit.startBLE();

  // Set initial page to Control
  RadioKit.setActivePage(0);
}

#endif // RADIOKIT_UI_H

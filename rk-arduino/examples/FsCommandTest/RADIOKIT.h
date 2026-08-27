/*__RADIOKIT_Designer_Config__
{
  "version": 2,
  "config": {
    "name": "FS Command Test",
    "description": "Test REPLACE and CRC32 commands",
    "transports": {
      "ble": { "enabled": false },
      "wifi": { "enabled": false, "ssid": "", "pass": "" },
      "cloud": { "enabled": false, "account": "", "relay": "" }
    },
    "theme": "dragon"
  },
  "pages": [
    {
      "name": "Main",
      "orientation": "landscape",
      "widgets": []
    }
  ]
}
RADIOKIT_Designer_Config__*/

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKitLib.h>

static inline void initRadioKit() {
  RadioKit.config.name = "FS Command Test";
  RadioKit.config.description = "Test REPLACE and CRC32 commands";

  RadioKit.begin();

  RadioKit.startSerial(Serial);
}

#endif // RADIOKIT_UI_H

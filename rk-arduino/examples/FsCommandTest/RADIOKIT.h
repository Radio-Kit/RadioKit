/*__RADIOKIT_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "FS Command Test",
    "description": "Test REPLACE and CRC32 commands",
    "transport": "SERIAL",
    "theme": "dragon"
  },
  "widgets": []
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

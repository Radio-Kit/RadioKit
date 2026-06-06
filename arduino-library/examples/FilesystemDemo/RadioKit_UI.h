/*__RadioKit_UI_Designer_Config__
{
  "version": 1,
  "config": {
    "name": "FS Demo",
    "description": "Bulk filesystem protocol demonstration",
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
  "widgets": []
}
RadioKit_UI_Designer_Config__*/
//__Might_Be_Overwritten_

#ifndef RADIOKIT_UI_H
#define RADIOKIT_UI_H

#include <RadioKit.h>

// ─── Config Init ───
static inline void initRadioKit() {
  RadioKit.config.name        = "FS Demo";
  RadioKit.config.description = "Bulk filesystem protocol demonstration";
  RadioKit.config.theme       = RK_DEFAULT;
  RadioKit.config.password    = "1234";

  RadioKit.begin();
  RadioKit.startSerial(Serial);
}

#endif // RADIOKIT_UI_H

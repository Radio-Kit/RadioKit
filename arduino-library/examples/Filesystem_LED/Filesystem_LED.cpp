/**
 * FilesystemDemo — RadioKit Example
 *
 * Demonstrates the bulk-FS protocol (0xAA):
 *   - Mounts LittleFS at startup
 *   - On first boot, creates a /demo directory and writes a README
 *   - Responds to FS_LIST, FS_READ, FS_INFO, FS_DELETE, FS_MKDIR, etc.
 *
 * Pair this with the Flutter app's "DEVICE_FS" tool.
 *
 * Compatible with both BLE and Serial transports. To switch, change
 * RadioKit.config.transport below.
 */

#include <Arduino.h>
#include "RadioKit_UI.h"

void setup() {
    Serial.begin(115200);
    pinMode(7, OUTPUT);
    digitalWrite(7, LOW);

    initRadioKit();

    // Mount the bulk-FS partition. Returns false if LittleFS is unavailable
    // (very rare on ESP32, common on other MCUs).
    if (!RadioKit.beginFs()) {
        Serial.println("FS: LittleFS not available — FS commands will return NO_FS");
    } else {
        Serial.printf("FS: mounted, total=%u, used=%u\n",
                      (unsigned)LittleFS.totalBytes(),
                      (unsigned)LittleFS.usedBytes());

        // Seed a demo file the first time the sketch boots.
        if (!LittleFS.exists("/demo/README.txt")) {
            LittleFS.mkdir("/demo");
            File f = LittleFS.open("/demo/README.txt", "w");
            if (f) {
                f.print("Hello from RadioKit bulk-FS!\n");
                f.print("Edit this file from the app.\n");
                f.close();
            }
        }
    }
}

void loop() {
    RadioKit.update();
}

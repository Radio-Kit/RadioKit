/**
 * Filesystem_LED — RadioKit Example
 *
 * Demonstrates USB Serial transport + bulk-FS protocol (0xAA):
 *   - Mounts LittleFS at startup
 *   - On first boot, creates a /demo directory and writes a README
 *   - Responds to FS_LIST, FS_READ, FS_INFO, FS_DELETE, FS_MKDIR, etc.
 *   - Slide switch toggles LED on GPIO 40
 *
 * Pair this with the Flutter app's remote filesystem tool.
 */

#include <Arduino.h>
#include "RADIOKIT.h"

static const int LED_PIN = 40;
static bool lastSwitchState = false;

void setup() {
    Serial.begin(115200);
    delay(2000);  // Give time for USB Serial to connect
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    initRadioKit();

#if RK_FS_HAS_LITTLEFS
    // Mount the bulk-FS partition. Returns false if LittleFS is unavailable.
    if (!RadioKit.beginFs()) {
        Serial.println("FS: LittleFS not available — FS commands will return NO_FS");
    } else {
#if RK_ARCH_DETECTED == RK_ARCH_ESP32
        Serial.printf("FS: mounted, total=%u, used=%u\n",
                      (unsigned)LittleFS.totalBytes(),
                      (unsigned)LittleFS.usedBytes());
#else
        Serial.println("FS: mounted");
#endif

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
#else
    Serial.println("FS: LittleFS not available on this platform");
#endif
}

void loop() {
    RadioKit.update();

    bool switchNow = slide_switch_1.rk.state;
    if (switchNow != lastSwitchState) {
        lastSwitchState = switchNow;
        digitalWrite(LED_PIN, switchNow ? HIGH : LOW);
        Serial.printf("LED: %s\n", switchNow ? "ON" : "OFF");
    }
}

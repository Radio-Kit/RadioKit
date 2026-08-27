/**
 * RadioKitLib.h
 * Main user-facing header for the RadioKit Arduino library (v2.0).
 *
 * Sketch pattern:
 *   1. Declare widget objects globally (they self-register)
 *   2. Set RadioKit.config fields
 *   3. Call RadioKit.begin() then RadioKit.startBLE() or RadioKit.startSerial()
 *   4. Call RadioKit.update() every loop()
 *
 * Note: The RadioKitClass definition lives in RadioKitClass.h to keep
 * compilation units that only need the class definition (e.g. RadioKitBLE.cpp)
 * from pulling in WiFi/Cloud headers that require extra dependencies.
 */

#ifndef RADIOKIT_H
#define RADIOKIT_H

#include "RadioKitClass.h"
#include "core/ICommandHandler.h"
#include "core/TransportManager.h"
#include "core/CommandDispatcher.h"
#include "handlers/ControlCommandHandler.h"
#include "handlers/SettingsCommandHandler.h"
#include "handlers/FsCommandHandler.h"
#include "handlers/OtaCommandHandler.h"
#include "handlers/PrintCommandHandler.h"
#include "connection/RadioKitBLE.h"
#include "connection/RadioKitSerial.h"
#include "connection/RadioKitFS.h"
#include "connection/RadioKitFsHandlers.h"
#include "connection/RadioKitOTA.h"
#include "connection/RadioKitSettings.h"
#include "connection/RadioKitPrint.h"
#include "connection/RadioKitNVS.h"
#include "connection/RadioKitWiFi.h"
#include "connection/RadioKitCloud.h"

#include "RadioKitWidgets.h"

#endif // RADIOKIT_H

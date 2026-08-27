package com.rambros3d.radiokit

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val rawUsbChannel = "com.rambros3d.radiokit/raw_usb"
    private val wifiLockChannel = "com.rambros3d.radiokit/wifi_lock"
    private var rawUsbPlugin: RawUsbPlugin? = null

    private var wifiLock: WifiManager.WifiLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        rawUsbPlugin = RawUsbPlugin(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, rawUsbChannel)
            .setMethodCallHandler(rawUsbPlugin)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiLockChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireWifiLock" -> {
                        val success = acquireLocks()
                        result.success(success)
                    }
                    "releaseWifiLock" -> {
                        releaseLocks()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireLocks(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

            if (wifiLock == null) {
                @Suppress("DEPRECATION")
                wifiLock = wifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "RadioKitRemoteAccess")
                wifiLock?.setReferenceCounted(false)
            }
            if (wifiLock?.isHeld == false) {
                wifiLock?.acquire()
            }

            if (multicastLock == null) {
                multicastLock = wifiManager.createMulticastLock("RadioKitMulticast")
                multicastLock?.setReferenceCounted(false)
            }
            if (multicastLock?.isHeld == false) {
                multicastLock?.acquire()
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun releaseLocks() {
        try {
            if (wifiLock?.isHeld == true) {
                wifiLock?.release()
            }
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        releaseLocks()
        rawUsbPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

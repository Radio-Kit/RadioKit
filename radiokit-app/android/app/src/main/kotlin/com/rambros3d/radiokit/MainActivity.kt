package com.rambros3d.radiokit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val rawUsbChannel = "com.rambros3d.radiokit/raw_usb"
    private var rawUsbPlugin: RawUsbPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        rawUsbPlugin = RawUsbPlugin(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, rawUsbChannel)
            .setMethodCallHandler(rawUsbPlugin)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        rawUsbPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

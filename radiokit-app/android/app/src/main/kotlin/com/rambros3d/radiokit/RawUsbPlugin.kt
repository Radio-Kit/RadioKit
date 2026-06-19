package com.rambros3d.radiokit

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import java.nio.ByteBuffer

/**
 * Raw USB write plugin that bypasses the mik3y Java library and writes directly
 * to the CDC ACM bulk OUT endpoint using Android's UsbDeviceConnection API.
 *
 * Key difference from the Java library: this plugin sends CLEAR_FEATURE(ENDPOINT_HALT)
 * before each write to recover from STALL conditions on the ESP32-S3 USB Serial/JTAG
 * controller's bulk OUT endpoint.
 */
class RawUsbPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "RawUsb"
        private const val CHANNEL = "com.rambros3d.radiokit/raw_usb"
        private const val ACTION_USB_PERMISSION = "com.rambros3d.radiokit.USB_PERMISSION"

        // CDC ACM constants
        private const val USB_RT_ACM = 0x21 // USB_TYPE_CLASS | USB_RECIP_INTERFACE
        private const val SET_LINE_CODING = 0x20
        private const val SET_CONTROL_LINE_STATE = 0x22
        private const val USB_CLASS_COMM = 0x02
        private const val USB_SUBCLASS_ACM = 0x02
        private const val USB_CLASS_CDC_DATA = 0x0A

        // USB control transfer constants for STALL recovery
        private const val USB_DIR_OUT = 0x00
        private const val USB_TYPE_STANDARD = 0x00
        private const val USB_RECIP_ENDPOINT = 0x02
        private const val CLEAR_FEATURE = 0x01
        private const val ENDPOINT_HALT = 0x00
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var connection: UsbDeviceConnection? = null
    private var device: UsbDevice? = null
    private var controlInterface: UsbInterface? = null
    private var dataInterface: UsbInterface? = null
    private var writeEndpoint: UsbEndpoint? = null
    private var readEndpoint: UsbEndpoint? = null
    private var controlIndex: Int = 0
    private var isOpen = false

    // Permission handling
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            if (intent.action == ACTION_USB_PERMISSION) {
                val dev = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                val result = pendingPermissionResult
                pendingPermissionResult = null
                if (granted && dev != null) {
                    result?.success(true)
                } else {
                    result?.error("NO_PERMISSION", "USB permission denied", null)
                }
            }
        }
    }

    init {
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbPermissionReceiver, filter)
        }
    }

    // Track STALL recovery attempts
    private var stallClearedCount = 0
    private var totalWriteAttempts = 0
    private var failedWriteAttempts = 0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listPorts" -> handleListPorts(result)
            "requestPermission" -> handleRequestPermission(call, result)
            "open" -> handleOpen(call, result)
            "write" -> handleWrite(call, result)
            "read" -> handleRead(call, result)
            "close" -> handleClose(result)
            "getStatus" -> handleGetStatus(result)
            else -> result.notImplemented()
        }
    }

    private fun handleListPorts(result: MethodChannel.Result) {
        val ports = mutableListOf<Map<String, Any?>>()
        for ((_, dev) in usbManager.deviceList) {
            val productName = dev.productName ?: dev.manufacturerName ?: ""
            ports.add(mapOf(
                "name" to dev.deviceName,
                "productName" to productName,
                "vendorId" to dev.vendorId,
                "productId" to dev.productId,
                "hasPermission" to usbManager.hasPermission(dev),
            ))
        }
        Log.d(TAG, "Listed ${ports.size} USB device(s)")
        result.success(ports)
    }

    private fun handleRequestPermission(call: MethodCall, result: MethodChannel.Result) {
        val deviceName = call.argument<String>("name") ?: return result.error("INVALID_ARGS", "Missing name", null)
        val dev = usbManager.deviceList.values.find { it.deviceName == deviceName }
            ?: return result.error("NOT_FOUND", "Device not found: $deviceName", null)

        if (usbManager.hasPermission(dev)) {
            result.success(true)
            return
        }

        pendingPermissionResult = result
        val flags = if (android.os.Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        val permissionIntent = PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_USB_PERMISSION), flags
        )
        usbManager.requestPermission(dev, permissionIntent)
    }

    private fun handleOpen(call: MethodCall, result: MethodChannel.Result) {
        val deviceName = call.argument<String>("name")
        val baudRate = call.argument<Int>("baudRate") ?: 1000000

        if (deviceName == null) {
            result.error("INVALID_ARGS", "Missing 'name' argument", null)
            return
        }

        Log.d(TAG, "Opening device: $deviceName at $baudRate baud")

        // Close any existing connection
        closeInternal()

        // Find the USB device
        val targetDevice = usbManager.deviceList.values.find { it.deviceName == deviceName }
        if (targetDevice == null) {
            Log.e(TAG, "Device not found: $deviceName")
            Log.d(TAG, "Available devices: ${usbManager.deviceList.values.map { it.deviceName }}")
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }

        this.device = targetDevice

        // Check permission
        if (!usbManager.hasPermission(targetDevice)) {
            Log.e(TAG, "No USB permission for $deviceName")
            result.error("NO_PERMISSION", "No USB permission for $deviceName. Call requestPermission first.", null)
            return
        }

        // Open connection
        val conn = usbManager.openDevice(targetDevice)
        if (conn == null) {
            Log.e(TAG, "Failed to open USB device: $deviceName — is it claimed by another app?")
            result.error("OPEN_FAILED", "Failed to open USB device. Is it claimed by another app?", null)
            return
        }
        this.connection = conn

        // Log all interfaces for debugging
        Log.d(TAG, "Device has ${targetDevice.interfaceCount} interfaces:")
        for (i in 0 until targetDevice.interfaceCount) {
            val iface = targetDevice.getInterface(i)
            Log.d(TAG, "  Interface $i: id=${iface.id} class=0x${iface.interfaceClass.toString(16)} " +
                    "subclass=0x${iface.interfaceSubclass.toString(16)} endpointCount=${iface.endpointCount}")
            for (j in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(j)
                Log.d(TAG, "    Endpoint $j: address=0x${ep.address.toString(16)} " +
                        "direction=${if (ep.direction == UsbConstants.USB_DIR_IN) "IN" else "OUT"} " +
                        "type=${ep.type} maxPacketSize=${ep.maxPacketSize}")
            }
        }

        // Find CDC ACM interfaces
        for (i in 0 until targetDevice.interfaceCount) {
            val iface = targetDevice.getInterface(i)
            if (iface.interfaceClass == USB_CLASS_COMM && iface.interfaceSubclass == USB_SUBCLASS_ACM) {
                controlInterface = iface
                controlIndex = iface.id
                Log.d(TAG, "Found control interface: id=${iface.id}")
            }
            if (iface.interfaceClass == USB_CLASS_CDC_DATA) {
                dataInterface = iface
                Log.d(TAG, "Found data interface: id=${iface.id}")
            }
        }

        // Fallback: try single-interface mode
        if (controlInterface == null || dataInterface == null) {
            Log.d(TAG, "No separate CDC interfaces found, trying single-interface mode")
            val iface = targetDevice.getInterface(0)
            controlInterface = iface
            dataInterface = iface
            controlIndex = 0
        }

        if (controlInterface == null || dataInterface == null) {
            closeInternal()
            result.error("NO_CDC", "No CDC ACM interfaces found", null)
            return
        }

        // Claim control interface (force=true to steal from other drivers)
        conn.claimInterface(controlInterface!!, true)

        // Claim data interface
        conn.claimInterface(dataInterface!!, true)

        // Find bulk endpoints on data interface
        for (i in 0 until dataInterface!!.endpointCount) {
            val ep = dataInterface!!.getEndpoint(i)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (ep.direction == UsbConstants.USB_DIR_IN) {
                    readEndpoint = ep
                    Log.d(TAG, "Read endpoint: 0x${ep.address.toString(16)} maxPacketSize=${ep.maxPacketSize}")
                }
                if (ep.direction == UsbConstants.USB_DIR_OUT) {
                    writeEndpoint = ep
                    Log.d(TAG, "Write endpoint: 0x${ep.address.toString(16)} maxPacketSize=${ep.maxPacketSize}")
                }
            }
        }

        // Fallback: check all interfaces for bulk endpoints
        if (writeEndpoint == null) {
            Log.d(TAG, "No bulk OUT on data interface, checking all interfaces...")
            for (i in 0 until targetDevice.interfaceCount) {
                val iface = targetDevice.getInterface(i)
                for (j in 0 until iface.endpointCount) {
                    val ep = iface.getEndpoint(j)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                        if (ep.direction == UsbConstants.USB_DIR_OUT && writeEndpoint == null) {
                            writeEndpoint = ep
                            Log.d(TAG, "Fallback write endpoint on interface ${iface.id}: 0x${ep.address.toString(16)}")
                        }
                        if (ep.direction == UsbConstants.USB_DIR_IN && readEndpoint == null) {
                            readEndpoint = ep
                            Log.d(TAG, "Fallback read endpoint on interface ${iface.id}: 0x${ep.address.toString(16)}")
                        }
                    }
                }
            }
        }

        if (writeEndpoint == null) {
            closeInternal()
            result.error("NO_ENDPOINT", "No bulk OUT endpoint found", null)
            return
        }

        // Send SET_LINE_CODING (baud rate)
        val baud = baudRate
        val lineCoding = byteArrayOf(
            (baud and 0xFF).toByte(),
            ((baud shr 8) and 0xFF).toByte(),
            ((baud shr 16) and 0xFF).toByte(),
            ((baud shr 24) and 0xFF).toByte(),
            0x00, // stop bits (1)
            0x00, // parity (none)
            0x08  // data bits (8)
        )
        val lineResult = conn.controlTransfer(USB_RT_ACM, SET_LINE_CODING, 0, controlIndex, lineCoding, lineCoding.size, 5000)
        Log.d(TAG, "SET_LINE_CODING ($baud baud): result=$lineResult")

        // Send SET_CONTROL_LINE_STATE (DTR=1, RTS=1)
        val dtrRtsResult = conn.controlTransfer(USB_RT_ACM, SET_CONTROL_LINE_STATE, 0x03, controlIndex, null, 0, 5000)
        Log.d(TAG, "SET_CONTROL_LINE_STATE (DTR+RTS): result=$dtrRtsResult")

        isOpen = true
        stallClearedCount = 0
        totalWriteAttempts = 0
        failedWriteAttempts = 0

        Log.d(TAG, "Device opened successfully")
        result.success(mapOf(
            "ok" to true,
            "writeEndpoint" to "0x${writeEndpoint!!.address.toString(16)}",
            "readEndpoint" to (readEndpoint?.let { "0x${it.address.toString(16)}" } ?: "none"),
            "maxPacketSize" to writeEndpoint!!.maxPacketSize
        ))
    }

    private fun handleWrite(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.error("INVALID_ARGS", "Missing 'data' argument", null)
            return
        }

        val conn = connection
        val ep = writeEndpoint
        if (conn == null || ep == null) {
            result.error("NOT_OPEN", "Device not open", null)
            return
        }

        totalWriteAttempts++

        // Strategy 1: Direct bulkTransfer
        var actual = conn.bulkTransfer(ep, data, data.size, 5000)
        Log.v(TAG, "bulkTransfer: sent ${data.size} bytes, actual=$actual")

        if (actual >= 0) {
            result.success(mapOf("bytes" to actual, "method" to "bulk"))
            return
        }

        // Strategy 2: Clear STALL and retry
        Log.w(TAG, "bulkTransfer returned $actual — attempting STALL recovery...")
        stallClearedCount++

        // Send CLEAR_FEATURE(ENDPOINT_HALT) to the OUT endpoint
        val clearResult = conn.controlTransfer(
            (USB_DIR_OUT or USB_TYPE_STANDARD or USB_RECIP_ENDPOINT),
            CLEAR_FEATURE,
            ENDPOINT_HALT,
            ep.address,
            null, 0, 5000
        )
        Log.d(TAG, "CLEAR_FEATURE(ENDPOINT_HALT) on 0x${ep.address.toString(16)}: result=$clearResult")

        actual = conn.bulkTransfer(ep, data, data.size, 5000)
        Log.d(TAG, "Retry bulkTransfer after STALL clear: actual=$actual")

        if (actual >= 0) {
            result.success(mapOf("bytes" to actual, "method" to "bulk_after_stall_clear"))
            return
        }

        // Strategy 3: Release and re-claim data interface, then retry
        Log.w(TAG, "Retry also failed — attempting interface re-claim...")
        try {
            conn.releaseInterface(dataInterface!!)
            Thread.sleep(50)
            conn.claimInterface(dataInterface!!, true)
            Thread.sleep(50)

            // Clear STALL again after re-claim
            conn.controlTransfer(
                (USB_DIR_OUT or USB_TYPE_STANDARD or USB_RECIP_ENDPOINT),
                CLEAR_FEATURE,
                ENDPOINT_HALT,
                ep.address,
                null, 0, 5000
            )

            actual = conn.bulkTransfer(ep, data, data.size, 5000)
            Log.d(TAG, "Retry after interface re-claim: actual=$actual")

            if (actual >= 0) {
                result.success(mapOf("bytes" to actual, "method" to "bulk_after_reclaim"))
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "Interface re-claim failed: ${e.message}")
        }

        // Strategy 4: Try UsbRequest (async) write
        Log.w(TAG, "All bulkTransfer attempts failed — trying UsbRequest...")
        try {
            val request = UsbRequest()
            request.initialize(conn, ep)
            val buffer = ByteBuffer.wrap(data)
            request.queue(buffer, data.size)

            val completed = conn.requestWait()
            request.close()

            if (completed != null) {
                Log.d(TAG, "UsbRequest completed")
                result.success(mapOf("bytes" to data.size, "method" to "usb_request"))
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "UsbRequest failed: ${e.message}")
        }

        failedWriteAttempts++
        Log.e(TAG, "All write strategies failed. Total attempts: $totalWriteAttempts, failed: $failedWriteAttempts, stalls cleared: $stallClearedCount")
        result.error("WRITE_FAILED", "All write strategies failed. stalls cleared=$stallClearedCount", null)
    }

    private fun handleRead(call: MethodCall, result: MethodChannel.Result) {
        val conn = connection
        val ep = readEndpoint
        if (conn == null || ep == null) {
            result.error("NOT_OPEN", "Device not open", null)
            return
        }

        val maxLen = call.argument<Int>("maxLength") ?: ep.maxPacketSize
        val timeout = call.argument<Int>("timeout") ?: 5000

        val buffer = ByteArray(maxLen)
        val actual = conn.bulkTransfer(ep, buffer, buffer.size, timeout)

        if (actual > 0) {
            val data = buffer.copyOf(actual)
            result.success(data)
        } else {
            result.success(null) // No data available
        }
    }

    private fun handleClose(result: MethodChannel.Result) {
        closeInternal()
        Log.d(TAG, "Device closed. Stats: totalWrites=$totalWriteAttempts, failed=$failedWriteAttempts, stallsCleared=$stallClearedCount")
        result.success(true)
    }

    private fun handleGetStatus(result: MethodChannel.Result) {
        result.success(mapOf(
            "isOpen" to isOpen,
            "totalWrites" to totalWriteAttempts,
            "failedWrites" to failedWriteAttempts,
            "stallsCleared" to stallClearedCount,
            "deviceName" to device?.deviceName,
            "writeEndpoint" to writeEndpoint?.let { "0x${it.address.toString(16)}" },
            "readEndpoint" to readEndpoint?.let { "0x${it.address.toString(16)}" }
        ))
    }

    private fun closeInternal() {
        isOpen = false
        try {
            if (controlInterface != null) connection?.releaseInterface(controlInterface!!)
        } catch (_: Exception) {}
        try {
            if (dataInterface != null) connection?.releaseInterface(dataInterface!!)
        } catch (_: Exception) {}
        try {
            connection?.close()
        } catch (_: Exception) {}
        connection = null
        device = null
        controlInterface = null
        dataInterface = null
        writeEndpoint = null
        readEndpoint = null
    }
}

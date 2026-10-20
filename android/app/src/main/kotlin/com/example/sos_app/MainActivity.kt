package com.example.sos_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.util.Log
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ble: BleTransportBridge? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        Log.d("BleTransportBridge", "configureFlutterEngine: creating BLE bridge")
        MethodChannel(engine.dartExecutor.binaryMessenger, "sos_app/external_links")
            .setMethodCallHandler { call, result ->
                val uri = (call.arguments as? String)?.let { Uri.parse(it) }
                if (call.method != "open" || uri?.scheme != "https" ||
                    uri.host !in setOf("www.openstreetmap.org", "www.geoapify.com")) {
                    result.error("invalid_link", "Unsupported attribution link", null)
                } else {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("open_failed", "Unable to open attribution", null)
                    }
                }
            }
        ble = BleTransportBridge(this, engine.dartExecutor.binaryMessenger).also { it.register() }
    }
    override fun onDestroy() {
        Log.d("BleTransportBridge", "MainActivity.onDestroy: disposing BLE bridge")
        ble?.dispose()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (ble?.onRequestPermissionsResult(requestCode, permissions, grantResults) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}

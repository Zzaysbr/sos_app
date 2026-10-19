package com.example.sos_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.util.Log

class MainActivity : FlutterActivity() {
    private var ble: BleTransportBridge? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        Log.d("BleTransportBridge", "configureFlutterEngine: creating BLE bridge")
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

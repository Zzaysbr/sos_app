package com.n1cxltine.sosapp

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val app get() = application as SosApplication
    override fun provideFlutterEngine(context: Context): FlutterEngine = app.engine()
    override fun shouldDestroyEngineWithHost(): Boolean = false
    override fun configureFlutterEngine(engine: FlutterEngine) {
        // The application registered plugins/channels before starting Dart.
        app.ble.activity = this
        app.background.activity = this
    }
    override fun onResume() {
        super.onResume()
        app.background.foreground = true
    }
    override fun onPause() {
        app.background.foreground = false
        super.onPause()
    }
    override fun onDestroy() {
        if (app.ble.activity === this) app.ble.activity = null
        if (app.background.activity === this) app.background.activity = null
        // A foreground service may still be receiving BLE frames. Its engine
        // and radio are owned by the application, not this activity instance.
        super.onDestroy()
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        if (!app.background.onPermissionsResult(code, results) &&
            !app.ble.onRequestPermissionsResult(code, permissions, results)) {
            super.onRequestPermissionsResult(code, permissions, results)
        }
    }
}

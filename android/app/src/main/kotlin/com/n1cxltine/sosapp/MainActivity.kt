package com.n1cxltine.sosapp

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
        MethodChannel(engine.dartExecutor.binaryMessenger, "sos_app/preferences")
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences("sos_ui", MODE_PRIVATE)
                when (call.method) {
                    "getPreferredRole" -> result.success(preferences.getString("preferred_role", null))
                    "setPreferredRole" -> {
                        val role = call.arguments as? String
                        if (role !in setOf("needHelp", "rescue")) {
                            result.error("invalid_role", "Unsupported role preference", null)
                        } else if (preferences.edit().putString("preferred_role", role).commit()) {
                            result.success(null)
                        } else {
                            result.error("storage_failed", "Unable to persist role preference", null)
                        }
                    }
                    "getPreferredLanguage" ->
                        result.success(preferences.getString("preferred_language", null))
                    "setPreferredLanguage" -> {
                        val language = call.arguments as? String
                        if (language !in setOf("en", "th")) {
                            result.error("invalid_language", "Unsupported language preference", null)
                        } else if (preferences.edit().putString("preferred_language", language).commit()) {
                            result.success(null)
                        } else {
                            result.error("storage_failed", "Unable to persist language preference", null)
                        }
                    }
                    "getRelayParticipationEnabled" ->
                        result.success(preferences.getBoolean("relay_participation_enabled", false))
                    "setRelayParticipationEnabled" -> {
                        val enabled = call.arguments as? Boolean
                        if (enabled == null) {
                            result.error("invalid_relay_preference", "Relay preference must be boolean", null)
                        } else if (preferences.edit()
                                .putBoolean("relay_participation_enabled", enabled)
                                .commit()) {
                            result.success(null)
                        } else {
                            result.error("storage_failed", "Unable to persist relay preference", null)
                        }
                    }
                    "getEmergencyConsent" -> result.success(mapOf(
                        "configured" to preferences.getBoolean("emergency_consent_configured", false),
                        "allowPublicRelay" to preferences.getBoolean("emergency_public_relay", false),
                        "allowVoluntaryRescue" to preferences.getBoolean("emergency_voluntary_rescue", false),
                        "shareLocation" to preferences.getBoolean("emergency_relay_location", false),
                    ))
                    "setEmergencyConsent" -> {
                        val value = call.arguments as? Map<*, *>
                        val configured = value?.get("configured") as? Boolean
                        val allowPublicRelay = value?.get("allowPublicRelay") as? Boolean
                        val shareLocation = value?.get("shareLocation") as? Boolean
                        val allowVoluntaryRescue = value?.get("allowVoluntaryRescue") as? Boolean ?: false
                        if (configured == null || allowPublicRelay == null || shareLocation == null ||
                            (shareLocation && !allowPublicRelay)) {
                            result.error("invalid_emergency_consent", "Emergency consent is invalid", null)
                        } else if (preferences.edit()
                                .putBoolean("emergency_consent_configured", configured)
                                .putBoolean("emergency_public_relay", allowPublicRelay)
                                .putBoolean("emergency_relay_location", shareLocation)
                                .putBoolean("emergency_voluntary_rescue", allowVoluntaryRescue && allowPublicRelay)
                                .commit()) {
                            result.success(null)
                        } else {
                            result.error("storage_failed", "Unable to persist emergency consent", null)
                        }
                    }
                    else -> result.notImplemented()
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

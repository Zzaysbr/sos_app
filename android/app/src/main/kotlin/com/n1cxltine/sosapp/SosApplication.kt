package com.n1cxltine.sosapp

import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** The service and activity share exactly one isolate and BLE bridge. */
class SosApplication : Application() {
    private var retainedEngine: FlutterEngine? = null
    lateinit var ble: BleTransportBridge
        private set
    lateinit var background: BackgroundRuntime
        private set

    fun engine(): FlutterEngine {
        retainedEngine?.let { return it }
        val app = this
        val engine = FlutterEngine(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, "sos_app/external_links")
            .setMethodCallHandler { call, result ->
                val uri = (call.arguments as? String)?.let { Uri.parse(it) }
                if (call.method != "open" || uri?.scheme != "https" ||
                    uri.host !in setOf("www.openstreetmap.org", "www.geoapify.com")) {
                    result.error("invalid_link", "Unsupported attribution link", null)
                } else {
                    try {
                        app.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("open_failed", "Unable to open attribution", null)
                    }
                }
            }
        MethodChannel(engine.dartExecutor.binaryMessenger, "sos_app/preferences")
            .setMethodCallHandler { call, result ->
                val preferences = app.getSharedPreferences("sos_ui", Context.MODE_PRIVATE)
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
        ble = BleTransportBridge(app, engine.dartExecutor.binaryMessenger).also { it.register() }
        background = BackgroundRuntime(app, engine.dartExecutor.binaryMessenger)
        retainedEngine = engine
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return engine
    }
}

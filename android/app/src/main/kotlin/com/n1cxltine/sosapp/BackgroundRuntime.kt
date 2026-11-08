package com.n1cxltine.sosapp

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class BackgroundRuntime(private val app: Application, messenger: BinaryMessenger) {
    var activity: Activity? = null
    var foreground = false
    private var permissionResult: MethodChannel.Result? = null
    private val manager = app.getSystemService(NotificationManager::class.java)
    private val seen = app.getSharedPreferences("chat_notification_receipts", Context.MODE_PRIVATE)
    private val requestCode = 4102

    init {
        if (Build.VERSION.SDK_INT >= 26) {
        manager.createNotificationChannel(NotificationChannel(CHAT, "Emergency chat", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "New messages in SOS conversations"
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        })
        manager.createNotificationChannel(NotificationChannel(BLE, "Nearby SOS activity", NotificationManager.IMPORTANCE_LOW))
        }
        MethodChannel(messenger, "sos_app/background").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(app, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else if (activity == null || !foreground || permissionResult != null ||
                            seen.getBoolean("permission_requested", false)) {
                            result.success(false)
                        } else {
                            seen.edit().putBoolean("permission_requested", true).apply()
                            permissionResult = result
                            activity!!.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), requestCode)
                        }
                    }
                    "setBleBackground" -> {
                        val enabled = call.arguments == true
                        if (enabled) {
                            if (!foreground && !BleBackgroundService.active) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            ContextCompat.startForegroundService(app, Intent(app, BleBackgroundService::class.java))
                        } else app.stopService(Intent(app, BleBackgroundService::class.java))
                        result.success(enabled)
                    }
                    "notifyChat" -> {
                        val args = call.arguments as? Map<*, *> ?: error("Invalid notification")
                        val owner = args["ownerId"] as? String ?: error("Missing owner")
                        val id = args["messageId"] as? String ?: error("Missing message")
                        val text = args["text"] as? String ?: error("Missing preview")
                        require(text.isNotBlank() && text.length <= 2000)
                        require(owner.isNotEmpty() && id.isNotEmpty() && owner.length < 512 && id.length < 512)
                        val key = MessageDigest.getInstance("SHA-256").digest((owner + "\u0000" + id).toByteArray()).joinToString("") { "%02x".format(it) }
                        if (seen.contains(key)) { result.success(null); return@setMethodCallHandler }
                        if (!foreground && manager.areNotificationsEnabled()) {
                            val notification = builder(app, CHAT)
                                .setSmallIcon(R.drawable.ic_stat_sos)
                                .setContentTitle("Emergency")
                                .setContentText(text)
                                .setStyle(Notification.BigTextStyle().bigText(text))
                                .setVisibility(Notification.VISIBILITY_PRIVATE)
                                .setCategory(Notification.CATEGORY_MESSAGE)
                                .setAutoCancel(true).setOnlyAlertOnce(true)
                                .setContentIntent(openApp(app)).build()
                            // Stable tag avoids a second visible notification after a crash
                            // between OS acceptance and the durable deduplication receipt.
                            manager.notify(key, 2, notification)
                        } else if (!foreground) { result.success(null); return@setMethodCallHandler }
                        val edit = seen.edit()
                        if (seen.all.size >= 2048) seen.all.entries.sortedBy { it.value as? Long ?: 0L }.take(256).forEach { edit.remove(it.key) }
                        check(edit.putLong(key, System.currentTimeMillis()).commit())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("background_unavailable", "Background operation was not accepted", null)
            }
        }
    }
    fun onPermissionsResult(code: Int, results: IntArray): Boolean {
        if (code != requestCode) return false
        permissionResult?.success(results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
        return true
    }
    companion object {
        const val CHAT = "sos_chat_v1"
        const val BLE = "sos_ble_v1"
        fun builder(context: Context, channel: String): Notification.Builder =
            if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class BleBackgroundService : Service() {
    companion object { var active = false; private set }
    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(BackgroundRuntime.BLE, "Nearby SOS activity", NotificationManager.IMPORTANCE_LOW))
        startForeground(1, BackgroundRuntime.builder(this, BackgroundRuntime.BLE)
            .setSmallIcon(R.drawable.ic_stat_sos).setContentTitle("Emergency")
            .setContentText("Nearby SOS and chat are active")
            .setOngoing(true).setContentIntent(BackgroundRuntime.openApp(this)).build())
        active = true
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY
    override fun onDestroy() { active = false; super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}

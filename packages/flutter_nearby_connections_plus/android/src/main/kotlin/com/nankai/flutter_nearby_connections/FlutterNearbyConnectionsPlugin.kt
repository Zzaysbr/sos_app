package com.nankai.flutter_nearby_connections

import android.app.Activity
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

const val SERVICE_ID = "flutter_nearby_connections"

const val initNearbyService = "init_nearby_service"
const val startAdvertisingPeer = "start_advertising_peer"
const val startBrowsingForPeers = "start_browsing_for_peers"

const val stopAdvertisingPeer = "stop_advertising_peer"
const val stopBrowsingForPeers = "stop_browsing_for_peers"

const val invitePeer = "invite_peer"
const val disconnectPeer = "disconnect_peer"

const val sendMessage = "send_message"

const val INVOKE_CHANGE_STATE_METHOD = "invoke_change_state_method"
const val INVOKE_MESSAGE_RECEIVE_METHOD = "invoke_message_receive_method"

const val NEARBY_RUNNING = "nearby_running"

/** FlutterNearbyConnectionsPlugin */
class FlutterNearbyConnectionsPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel

    private var locationHelper: LocationHelper? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var callbackUtils: CallbackUtils? = null

    private var localDeviceName: String = ""
    private var strategy: Strategy = Strategy.P2P_POINT_TO_POINT
    private var connectionsClient: ConnectionsClient? = null
    private var serviceBindManager: ServiceBindManager? = null

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            VIEW_TYPE_ID
        )

        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        @NonNull call: MethodCall,
        @NonNull result: Result
    ) {
        val currentActivity = activity

        if (currentActivity == null) {
            result.error(
                "NO_ACTIVITY",
                "Nearby Connections requires an attached Android Activity.",
                null
            )
            return
        }

        try {
            when (call.method) {
                initNearbyService -> {
                    Log.d("nearby_connections", "initNearbyService")

                    callbackUtils = CallbackUtils(
                        channel,
                        currentActivity
                    )

                    connectionsClient = Nearby.getConnectionsClient(
                        currentActivity
                    )

                    serviceBindManager = ServiceBindManager(
                        currentActivity,
                        channel,
                        callbackUtils!!
                    )

                    serviceBindManager?.bindService()

                    localDeviceName =
                        call.argument<String>("deviceName")
                            ?.takeIf { it.isNotBlank() }
                            ?: "${Build.MANUFACTURER} ${Build.MODEL}"

                    strategy = when (call.argument<Int>("strategy")) {
                        0 -> Strategy.P2P_CLUSTER
                        1 -> Strategy.P2P_STAR
                        else -> Strategy.P2P_POINT_TO_POINT
                    }

                    locationHelper?.requestLocationPermission(result)
                }

                startAdvertisingPeer -> {
                    Log.d(
                        "nearby_connections",
                        "startAdvertisingPeer"
                    )

                    val deviceName =
                        call.argument<String>("deviceName")
                            ?.takeIf { it.isNotBlank() }
                            ?: localDeviceName

                    serviceBindManager
                        ?.mService
                        ?.startAdvertising(
                            strategy,
                            deviceName
                        )

                    result.success(true)
                }

                startBrowsingForPeers -> {
                    Log.d(
                        "nearby_connections",
                        "startBrowsingForPeers"
                    )

                    serviceBindManager
                        ?.mService
                        ?.startDiscovery(strategy)

                    result.success(true)
                }

                stopAdvertisingPeer -> {
                    Log.d(
                        "nearby_connections",
                        "stopAdvertisingPeer"
                    )

                    serviceBindManager
                        ?.mService
                        ?.stopAdvertising()

                    serviceBindManager?.unbindService()

                    result.success(true)
                }

                stopBrowsingForPeers -> {
                    Log.d(
                        "nearby_connections",
                        "stopBrowsingForPeers"
                    )

                    serviceBindManager
                        ?.mService
                        ?.stopDiscovery()

                    serviceBindManager?.unbindService()

                    result.success(true)
                }

                invitePeer -> {
                    Log.d(
                        "nearby_connections",
                        "invitePeer"
                    )

                    val deviceId = call.argument<String>("deviceId")
                    val displayName = call.argument<String>("deviceName")

                    if (deviceId.isNullOrBlank() || displayName.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "deviceId and deviceName are required.",
                            null
                        )
                        return
                    }

                    serviceBindManager
                        ?.mService
                        ?.connect(
                            deviceId,
                            displayName
                        )

                    result.success(true)
                }

                disconnectPeer -> {
                    Log.d(
                        "nearby_connections",
                        "disconnectPeer"
                    )

                    val deviceId = call.argument<String>("deviceId")

                    if (deviceId.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "deviceId is required.",
                            null
                        )
                        return
                    }

                    serviceBindManager
                        ?.mService
                        ?.disconnect(deviceId)

                    callbackUtils?.updateStatus(
                        deviceId = deviceId,
                        state = notConnected
                    )

                    result.success(true)
                }

                sendMessage -> {
                    Log.d(
                        "nearby_connections",
                        "sendMessage"
                    )

                    val deviceId = call.argument<String>("deviceId")
                    val message = call.argument<String>("message")

                    if (deviceId.isNullOrBlank() || message == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "deviceId and message are required.",
                            null
                        )
                        return
                    }

                    serviceBindManager
                        ?.mService
                        ?.sendStringPayload(
                            deviceId,
                            message
                        )

                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(
                "nearby_connections",
                "Method ${call.method} threw an exception",
                e
            )

            result.error(
                "EXCEPTION",
                "Method ${call.method} threw an exception.",
                e.message
            )
        }
    }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel.setMethodCallHandler(null)

        serviceBindManager?.mService?.stopAdvertising()
        serviceBindManager?.mService?.stopDiscovery()
        serviceBindManager?.unbindService()

        serviceBindManager = null
        connectionsClient = null
        callbackUtils = null
        locationHelper = null
    }

    override fun onAttachedToActivity(
        binding: ActivityPluginBinding
    ) {
        this.binding = binding
        this.activity = binding.activity

        val helper = LocationHelper(binding.activity)

        locationHelper = helper

        binding.addActivityResultListener(helper)
        binding.addRequestPermissionsResultListener(helper)
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding
    ) {
        this.binding = binding
        this.activity = binding.activity

        val helper = LocationHelper(binding.activity)

        locationHelper = helper

        binding.addActivityResultListener(helper)
        binding.addRequestPermissionsResultListener(helper)
    }

    override fun onDetachedFromActivity() {
        locationHelper?.let { helper ->
            binding?.removeRequestPermissionsResultListener(helper)
            binding?.removeActivityResultListener(helper)
        }

        locationHelper = null
        binding = null
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        locationHelper?.let { helper ->
            binding?.removeRequestPermissionsResultListener(helper)
            binding?.removeActivityResultListener(helper)
        }

        locationHelper = null
        binding = null
        activity = null
    }

    companion object {
        private const val VIEW_TYPE_ID = "flutter_nearby_connections"
    }
}
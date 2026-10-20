package com.example.sos_app

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.ArrayDeque

class BleTransportBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val TAG = "BleTransportBridge"
        val SERVICE: UUID = UUID.fromString("8b7f0001-6d3a-4c8b-9d21-5a7f2e110001")
        val RX: UUID = UUID.fromString("8b7f0002-6d3a-4c8b-9d21-5a7f2e110001")
        val TX: UUID = UUID.fromString("8b7f0003-6d3a-4c8b-9d21-5a7f2e110001")
        val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val methods = MethodChannel(messenger, "sos_ble_transport/methods")
    private val eventChannel = EventChannel(messenger, "sos_ble_transport/events")
    private val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter? = manager.adapter
    private var sink: EventChannel.EventSink? = null
    private var scanner: BluetoothLeScanner? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var server: BluetoothGattServer? = null
    private var serverTxCharacteristic: BluetoothGattCharacteristic? = null
    private var serverReady = false
    private var advertisingResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private val permissionRequestCode = 4101
    private var advertisingActive = false
    private var advertiseCallback: AdvertiseCallback? = null
    private val clients = mutableMapOf<String, BluetoothGatt>()
    private val readyClients = mutableSetOf<String>()
    private data class PendingGattWrite(val value: ByteArray, val result: MethodChannel.Result)
    private val writeQueues = mutableMapOf<String, ArrayDeque<PendingGattWrite>>()
    private val writeInFlight = mutableMapOf<String, PendingGattWrite>()
    private val writeTimeouts = mutableMapOf<String, Runnable>()
    private val gattWriteTimeoutMs = 5_000L
    private val notificationClients = mutableSetOf<String>()
    private val serverClients = mutableSetOf<String>()
    private val disconnectReasons = mutableMapOf<String, String>()
    private val setupTimeouts = mutableMapOf<String, Runnable>()
    private val connectionAttempts = mutableMapOf<String, Long>()
    private var nextConnectionAttempt = 0L
    private val gattSetupTimeoutMs = 15_000L
    private data class PendingNotification(val value: ByteArray, val result: MethodChannel.Result)
    private val notificationQueues = mutableMapOf<String, ArrayDeque<PendingNotification>>()
    private val notificationInFlight = mutableSetOf<String>()
    private val maxPendingNotifications = 32
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var disposed = false
    private var generation = 0
    private var scanSession = 0L

    fun register() {
        // A Flutter hot restart can replace the Dart channel while the
        // Android permission dialog is still open. Do not leave the old
        // MethodChannel result blocking the new Dart isolate.
        permissionResult?.error("restarted", "Flutter BLE channel was restarted", null)
        permissionResult = null
        disposed = false
        methods.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { dispose() }
            return
        }
        logDebug("dispose requested; activeCentral=${clients.size} serverClients=${serverClients.size} advertising=$advertisingActive")
        disposed = true
        generation += 1
        stopDiscovery()
        try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: SecurityException) { }
        advertiser = null
        advertiseCallback = null
        advertisingActive = false
        advertisingResult?.error("disposed", "BLE transport was disposed", null)
        advertisingResult = null
        permissionResult?.error("disposed", "BLE transport was disposed", null)
        permissionResult = null
        clients.values.toList().forEach {
            try { it.disconnect() } catch (_: SecurityException) { }
            try { it.close() } catch (_: SecurityException) { }
        }
        failAllGattWrites("disposed", "BLE transport was disposed")
        clients.clear()
        readyClients.clear()
        notificationClients.clear()
        serverClients.clear()
        notificationQueues.values.flatten().forEach {
            it.result.error("disposed", "BLE transport was disposed", null)
        }
        notificationQueues.clear()
        notificationInFlight.clear()
        disconnectReasons.clear()
        setupTimeouts.values.forEach(mainHandler::removeCallbacks)
        setupTimeouts.clear()
        connectionAttempts.clear()
        try { server?.close() } catch (_: SecurityException) { }
        server = null
        serverTxCharacteristic = null
        serverReady = false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { onListen(arguments, events) }
            return
        }
        sink = events
        emit(mapOf("type" to "state", "state" to adapterState()))
    }

    override fun onCancel(arguments: Any?) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { onCancel(arguments) }
            return
        }
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { onMethodCall(call, result) }
            return
        }
        if (call.method == "deviceIdentity") {
            val preferences = context.getSharedPreferences("sos_device", Context.MODE_PRIVATE)
            val identity = preferences.getString("identity", null) ?: UUID.randomUUID().toString().also {
                if (!preferences.edit().putString("identity", it).commit()) {
                    result.error("storage_failed", "Cannot persist device identity", null)
                    return
                }
            }
            result.success(identity)
            return
        }
        if (disposed && (call.method == "requestPermissions" || call.method == "initialize")) {
            disposed = false
        }
        if (disposed && call.method != "dispose") {
            result.error("disposed", "BLE transport was disposed", null)
            return
        }
        if (call.method == "requestPermissions") {
            requestPermissions(result)
            return
        }
        if (!hasPermissionFor(call.method)) {
            result.error("unauthorized", "Bluetooth permission is not granted for ${call.method}", null)
            emitError("Permission denied for ${call.method}")
            return
        }
        try {
            when (call.method) {
                "initialize" -> {
                    if (!checkAdapter(result)) return
                    ensureServer(result)
                }
                "startAdvertising" -> startAdvertising(result)
                "stopAdvertising" -> stopAdvertising(result)
                "startDiscovery" -> startDiscovery(result)
                "stopDiscovery" -> {
                    stopDiscovery()
                    result.success(null)
                }
                "connect" -> connect(call.argument<String>("deviceId"), result)
                "disconnect" -> disconnect(call.argument<String>("deviceId"), result)
                "send" -> send(call, result)
                "dispose" -> {
                    dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: SecurityException) {
            result.error("unauthorized", "Bluetooth permission was revoked", null)
            emitError(error.message ?: "Bluetooth permission was revoked")
        } catch (error: Exception) {
            result.error("ble_error", error.message, null)
            emitError(error.message ?: "Bluetooth operation failed")
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val permissions = if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (permissions.all { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }) {
            result.success(null)
            emit(mapOf("type" to "permissions", "state" to "granted"))
            return
        }
        if (permissionResult != null) {
            result.error("busy", "A Bluetooth permission request is already in progress", null)
            return
        }
        val activity = context as? Activity
        if (activity == null) {
            result.error("permission_unavailable", "Bluetooth permissions require an active Android activity", null)
            emitError("Bluetooth permission request requires an active activity")
            return
        }
        permissionResult = result
        logDebug("requesting Bluetooth permissions: ${permissions.joinToString()}")
        activity.requestPermissions(permissions, permissionRequestCode)
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != permissionRequestCode) return false
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { onRequestPermissionsResult(requestCode, permissions, grantResults) }
            return true
        }
        val result = permissionResult ?: return true
        permissionResult = null
        val granted = permissions.isNotEmpty() &&
            permissions.indices.all { index ->
                grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
            }
        logDebug("Bluetooth permission callback granted=$granted")
        if (granted) {
            result.success(null)
            emit(mapOf("type" to "permissions", "state" to "granted"))
        } else {
            result.error("permission_denied", "Bluetooth permissions were denied", null)
            emitError("Bluetooth permissions were denied")
        }
        return true
    }

    private fun hasPermissionFor(method: String): Boolean {
        if (Build.VERSION.SDK_INT >= 31) {
            val connect = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
            val scan = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
            val advertise = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED
            return when (method) {
                "startDiscovery", "stopDiscovery" -> scan && connect
                "startAdvertising", "stopAdvertising" -> advertise && connect
                "connect", "disconnect", "send", "initialize" -> connect
                else -> true
            }
        }
        return Build.VERSION.SDK_INT >= 31 || ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun checkAdapter(result: MethodChannel.Result): Boolean {
        if (adapter == null) {
            result.error("unsupported", "This device does not support Bluetooth LE", null)
            emitError("Bluetooth LE is unsupported")
            return false
        }
        if (!adapter.isEnabled) {
            result.error("powered_off", "Bluetooth is powered off", null)
            emitError("Bluetooth is powered off")
            return false
        }
        return true
    }

    private fun adapterState(): String {
        if (adapter == null) return "unsupported"
        if (!hasPermissionFor("initialize")) return "unauthorized"
        return try {
            if (adapter.isEnabled) "idle" else "poweredOff"
        } catch (_: SecurityException) {
            "unauthorized"
        }
    }

    private fun ensureServer(result: MethodChannel.Result? = null) {
        if (server != null) {
            result?.success(null)
            return
        }
        server = manager.openGattServer(context, serverCallback(generation))
        if (server == null) {
            result?.error("server_failed", "Could not open the GATT server", null)
            emitError("Could not open the GATT server")
            return
        }
        val service = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val rx = BluetoothGattCharacteristic(
            RX,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        val tx = BluetoothGattCharacteristic(
            TX,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        tx.addDescriptor(BluetoothGattDescriptor(CCCD, BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE))
        serverTxCharacteristic = tx
        service.addCharacteristic(rx)
        service.addCharacteristic(tx)
        serverReady = false
        if (!server!!.addService(service)) {
            server?.close()
            server = null
            result?.error("server_failed", "Could not add the GATT service", null)
            emitError("Could not add the GATT service")
            return
        }
        result?.success(null)
    }

    private fun startAdvertising(result: MethodChannel.Result) {
        if (advertisingResult != null || advertisingActive) {
            result.error("busy", "Advertising is already active or starting", null)
            return
        }
        if (!checkAdapter(result)) return
        advertisingResult = result
        ensureServer()
        if (serverReady) startAdvertisingNative()
    }

    private fun stopAdvertising(result: MethodChannel.Result) {
        advertiser?.stopAdvertising(advertiseCallback)
        advertiseCallback = null
        advertisingActive = false
        advertisingResult?.error("cancelled", "Advertising was stopped before it started", null)
        advertisingResult = null
        emit(mapOf("type" to "state", "state" to adapterState()))
        result.success(null)
    }

    private fun startAdvertisingNative() {
        val current = advertiser ?: adapter?.bluetoothLeAdvertiser
        advertiser = current
        if (current == null) {
            advertisingResult?.error("unsupported", "BLE advertising is unavailable", null)
            advertisingResult = null
            emitError("BLE advertising is unavailable")
            return
        }
        val callback = createAdvertiseCallback()
        advertiseCallback = callback
        try {
            current.startAdvertising(
                AdvertiseSettings.Builder()
                    .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                    .setConnectable(true)
                    .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                    .build(),
                AdvertiseData.Builder()
                    // A 128-bit UUID plus the device name can exceed the
                    // legacy 31-byte advertising packet. Put the name in the
                    // scan response so code 1 (DATA_TOO_LARGE) is avoided.
                    .setIncludeDeviceName(false)
                    .addServiceUuid(ParcelUuid(SERVICE))
                    .build(),
                AdvertiseData.Builder()
                    .setIncludeDeviceName(true)
                    .build(),
                callback,
            )
        } catch (error: Exception) {
            advertisingResult?.error("advertise_failed", error.message, null)
            advertisingResult = null
            advertiseCallback = null
            advertisingActive = false
            emitError(error.message ?: "Could not start advertising")
        }
    }

    private fun startDiscovery(result: MethodChannel.Result) {
        if (!checkAdapter(result)) return
        val current = adapter?.bluetoothLeScanner
        if (current == null) {
            result.error("unsupported", "BLE scanning is unavailable", null)
            emitError("BLE scanning is unavailable")
            return
        }
        scanner?.stopScan(scanCallback)
        scanner = current
        val session = ++scanSession
        scanCallback = createScanCallback(session)
        logDebug("scan start session=$session")
        try {
            current.startScan(
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                scanCallback,
            )
            emit(mapOf("type" to "state", "state" to "discovering", "scanSession" to session))
            result.success(null)
        } catch (error: Exception) {
            result.error("scan_failed", error.message, null)
            emitError(error.message ?: "Could not start scanning")
        }
    }

    private fun stopDiscovery() {
        try { scanner?.stopScan(scanCallback) } catch (_: Exception) { }
        scanner = null
        scanCallback = null
        scanSession += 1
        emit(mapOf("type" to "state", "state" to adapterState()))
    }

    private fun connect(id: String?, result: MethodChannel.Result) {
        if (id.isNullOrBlank()) {
            result.error("invalid_device", "A device id is required", null)
            return
        }
        val remote = try { adapter?.getRemoteDevice(id) } catch (_: IllegalArgumentException) { null }
        if (remote == null) {
            result.error("invalid_device", "Invalid Bluetooth device id", null)
            return
        }
        if (clients.containsKey(id)) {
            result.error("busy", "A connection already exists for this device", null)
            return
        }
        val gatt = remote.connectGatt(context, false, gattCallback)
        if (gatt == null) {
            result.error("connect_failed", "Android could not create a GATT connection", null)
            emitError("Could not create a GATT connection to $id")
            return
        }
        val attempt = ++nextConnectionAttempt
        connectionAttempts[id] = attempt
        clients[id] = gatt
        logDebug("connect attempt=$attempt id=$id")
        emit(mapOf("type" to "connecting", "device" to device(remote), "role" to "central", "attempt" to attempt))
        result.success(null)
    }

    private fun disconnect(id: String?, result: MethodChannel.Result) {
        if (id.isNullOrBlank()) {
            result.error("invalid_device", "A device id is required", null)
            return
        }
        disconnectReasons[id] = "flutter disconnect()"
        clients[id]?.let {
            logDebug("disconnect requested id=$id")
            failGattWrites(id, "disconnected", "BLE connection was disconnected")
            it.disconnect()
            // Wait for onConnectionStateChange before closing this object.
        }
        readyClients.remove(id)
        notificationClients.remove(id)
        cancelSetupTimeout(id)
        result.success(null)
    }

    private fun send(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("deviceId")
        val bytes = call.argument<ByteArray>("data")
        if (id.isNullOrBlank() || bytes == null) {
            result.error("invalid_data", "deviceId and data are required", null)
            return
        }
        val requestedRole = call.argument<String>("role")
        val usePeripheral = requestedRole == "peripheral" ||
            (requestedRole == null && !readyClients.contains(id) && notificationClients.contains(id))
        if (usePeripheral) {
            sendPeripheralNotification(id, bytes, result)
            return
        }
        val gatt = clients[id]
        val characteristic = gatt?.getService(SERVICE)?.getCharacteristic(RX)
        if (gatt == null || characteristic == null || !readyClients.contains(id)) {
            result.error("not_connected", "GATT is not ready for $id", null)
            return
        }
        // Android permits only one outstanding GATT write per connection. The
        // Dart coordinator sends frames sequentially, so this future must not
        // complete until onCharacteristicWrite confirms the native operation.
        val queue = writeQueues.getOrPut(id) { ArrayDeque() }
        queue.addLast(PendingGattWrite(bytes.copyOf(), result))
        flushGattWrites(id)
    }

    private fun flushGattWrites(id: String) {
        if (writeInFlight.containsKey(id)) return
        val queue = writeQueues[id] ?: return
        val pending = queue.firstOrNull() ?: run {
            writeQueues.remove(id)
            return
        }
        val gatt = clients[id]
        val characteristic = gatt?.getService(SERVICE)?.getCharacteristic(RX)
        if (gatt == null || characteristic == null || !readyClients.contains(id)) {
            failGattWrites(id, "not_connected", "GATT is no longer ready for $id")
            return
        }

        writeInFlight[id] = pending
        val timeout = Runnable {
            completeGattWrite(
                id,
                BluetoothGatt.GATT_FAILURE,
                "GATT write timed out for $id",
                continueQueue = false,
            )
            failGattWrites(id, "timeout", "GATT write queue timed out for $id")
            clients[id]?.disconnect()
        }
        writeTimeouts[id] = timeout
        mainHandler.postDelayed(timeout, gattWriteTimeoutMs)

        val accepted = try {
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            characteristic.value = pending.value
            gatt.writeCharacteristic(characteristic)
        } catch (error: Exception) {
            logError("GATT write threw for $id: ${error.message}")
            false
        }
        if (!accepted) {
            mainHandler.removeCallbacks(timeout)
            writeTimeouts.remove(id)
            writeInFlight.remove(id)
            if (queue.isNotEmpty()) queue.removeFirst()
            pending.result.error("write_failed", "Android rejected the GATT write", null)
            emitError("GATT write rejected for $id")
            flushGattWrites(id)
        }
    }

    private fun completeGattWrite(
        id: String,
        status: Int,
        failure: String? = null,
        continueQueue: Boolean = true,
    ) {
        val pending = writeInFlight.remove(id) ?: return
        writeTimeouts.remove(id)?.let(mainHandler::removeCallbacks)
        writeQueues[id]?.let { queue -> if (queue.isNotEmpty()) queue.removeFirst() }
        val gatt = clients[id]
        if (status == BluetoothGatt.GATT_SUCCESS) {
            pending.result.success(null)
            if (gatt != null) {
                emit(mapOf("type" to "sendAccepted", "device" to device(gatt.device), "role" to "central"))
            }
        } else {
            pending.result.error("write_failed", failure ?: "GATT write failed (status $status)", null)
            emitError(failure ?: "GATT write callback failed for $id (status $status)")
        }
        if (continueQueue) flushGattWrites(id)
    }

    private fun failGattWrites(id: String, code: String, message: String) {
        writeTimeouts.remove(id)?.let(mainHandler::removeCallbacks)
        writeInFlight.remove(id)?.result?.error(code, message, null)
        writeQueues.remove(id)?.forEach { it.result.error(code, message, null) }
    }

    private fun failAllGattWrites(code: String, message: String) {
        (writeQueues.keys + writeInFlight.keys).toSet().forEach {
            failGattWrites(it, code, message)
        }
    }

    private fun sendPeripheralNotification(
        id: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (server == null || !serverReady || !serverClients.contains(id) ||
            !notificationClients.contains(id) || serverTxCharacteristic == null) {
            result.error("not_ready", "Peripheral notification session is not ready for $id", null)
            return
        }
        val queue = notificationQueues.getOrPut(id) { ArrayDeque() }
        if (queue.size >= maxPendingNotifications) {
            result.error("backpressure", "Too many pending notifications for $id", null)
            return
        }
        queue.addLast(PendingNotification(bytes.copyOf(), result))
        flushPeripheralNotifications(id)
    }

    private fun flushPeripheralNotifications(id: String) {
        if (notificationInFlight.contains(id)) return
        val queue = notificationQueues[id] ?: return
        val pending = queue.firstOrNull() ?: run {
            notificationQueues.remove(id)
            return
        }
        val currentServer = server
        val tx = serverTxCharacteristic
        val device = try { adapter?.getRemoteDevice(id) } catch (_: IllegalArgumentException) { null }
        if (currentServer == null || tx == null || device == null ||
            !serverClients.contains(id) || !notificationClients.contains(id)) {
            queue.removeFirst()
            pending.result.error("not_ready", "Peripheral notification session is no longer ready for $id", null)
            flushPeripheralNotifications(id)
            return
        }
        logDebug("TX notification send id=$id bytes=${pending.value.size}")
        tx.value = pending.value
        val accepted = if (Build.VERSION.SDK_INT >= 33) {
            currentServer.notifyCharacteristicChanged(
                device,
                tx,
                false,
                pending.value,
            ) == BluetoothStatusCodes.SUCCESS
        } else {
            @Suppress("DEPRECATION")
            currentServer.notifyCharacteristicChanged(device, tx, false)
        }
        if (!accepted) {
            queue.removeFirst()
            pending.result.error("notification_failed", "Android rejected TX notification for $id", null)
            flushPeripheralNotifications(id)
            return
        }
        notificationInFlight.add(id)
    }

    private fun device(value: BluetoothDevice, rssi: Int? = null) = mapOf(
        "id" to value.address,
        "name" to value.name,
        "rssi" to rssi,
    )

    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block()
        else mainHandler.post(block)
    }

    private fun emit(value: Map<String, Any?>) {
        onMain {
            if (!disposed) sink?.success(value)
        }
    }

    private fun emitError(message: String) {
        logError(message)
        emit(mapOf("type" to "error", "error" to message))
    }

    private fun logDebug(message: String) {
        Log.d(TAG, "t=${System.currentTimeMillis()} $message")
    }

    private fun logError(message: String) {
        Log.e(TAG, "t=${System.currentTimeMillis()} $message")
    }

    private fun createAdvertiseCallback() = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            onMain {
                if (advertiseCallback !== this) {
                    logDebug("Ignoring stale advertising success callback")
                    return@onMain
                }
                logDebug("onStartSuccess advertising")
                advertisingActive = true
                advertisingResult?.success(null)
                advertisingResult = null
                emit(mapOf("type" to "state", "state" to "advertising"))
            }
        }

        override fun onStartFailure(errorCode: Int) {
            onMain {
                if (advertiseCallback !== this) {
                    logDebug("Ignoring stale advertising failure callback code=$errorCode")
                    return@onMain
                }
                val symbolic = when (errorCode) {
                    AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE -> "ADVERTISE_FAILED_DATA_TOO_LARGE"
                    AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "ADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                    AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED -> "ADVERTISE_FAILED_ALREADY_STARTED"
                    AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR -> "ADVERTISE_FAILED_INTERNAL_ERROR"
                    AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "ADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                    else -> "UNKNOWN"
                }
                val message = "Android advertising failed (code $errorCode, $symbolic)"
                logError("onStartFailure: $message")
                advertisingActive = false
                advertisingResult?.error("advertise_failed", message, errorCode)
                advertisingResult = null
                advertiseCallback = null
                emitError(message)
            }
        }
    }

    private var scanCallback: ScanCallback? = null

    private fun createScanCallback(session: Long) = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            onMain {
                if (disposed || session != scanSession) return@onMain
                logDebug("onScanResult session=$session callbackType=$callbackType id=${result.device.address} rssi=${result.rssi}")
                emit(mapOf("type" to "deviceFound", "device" to device(result.device, result.rssi), "scanSession" to session))
            }
        }
        override fun onScanFailed(errorCode: Int) {
            onMain {
                if (disposed || session != scanSession) return@onMain
                scanner = null
                emitError("Android scan failed (code $errorCode)")
            }
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            onMain { handleConnectionStateChange(gatt, status, newState) }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            onMain { handleServicesDiscovered(gatt, status) }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            onMain { handleDescriptorWrite(gatt, descriptor, status) }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            onMain {
                if (!isCurrentGatt(gatt)) {
                    logDebug("Ignoring stale characteristic write id=${gatt.device.address}")
                    return@onMain
                }
                logDebug("onCharacteristicWrite id=${gatt.device.address} uuid=${characteristic.uuid} status=$status")
                if (characteristic.uuid == RX) {
                    completeGattWrite(
                        gatt.device.address,
                        status,
                        if (status == BluetoothGatt.GATT_SUCCESS) null
                        else "GATT write callback failed for ${gatt.device.address} (status $status)",
                    )
                }
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            onMain {
                if (isCurrentGatt(gatt)) emitCharacteristicChanged(gatt, characteristic, characteristic.value)
                else logDebug("Ignoring stale characteristic notification id=${gatt.device.address}")
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            onMain {
                if (isCurrentGatt(gatt)) emitCharacteristicChanged(gatt, characteristic, value)
                else logDebug("Ignoring stale characteristic notification id=${gatt.device.address}")
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            onMain {
                logDebug("onMtuChanged id=${gatt.device.address} mtu=$mtu status=$status")
            }
        }
    }

    private fun emitCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        if (characteristic.uuid == TX && readyClients.contains(gatt.device.address)) {
            logDebug("TX notification received id=${gatt.device.address} bytes=${value.size}")
            emit(mapOf("type" to "data", "device" to device(gatt.device), "payload" to value, "role" to "central"))
        }
    }

    private fun handleConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
        val id = gatt.device.address
        val attempt = connectionAttempts[id]
        if (clients[id] !== gatt) {
            logDebug("Ignoring stale connection callback attempt=${attempt ?: "unknown"} id=$id status=$status newState=$newState")
            gatt.close()
            return
        }
        val reason = disconnectReasons[id] ?: "remote_or_stack"
        logDebug("onConnectionStateChange attempt=${attempt ?: "unknown"} id=$id status=$status newState=$newState reason=$reason")
        if (status != BluetoothGatt.GATT_SUCCESS) {
            failGattWrites(id, "disconnected", "GATT connection failed for $id (status $status)")
            cleanupCentral(id, gatt)
            emit(mapOf("type" to "error", "error" to "GATT connection failed for $id (status $status)", "device" to device(gatt.device), "role" to "central"))
            emit(mapOf("type" to "disconnected", "device" to device(gatt.device), "error" to "status $status", "role" to "central"))
            return
        }
        if (newState == BluetoothProfile.STATE_CONNECTED) {
            scheduleSetupTimeout(id, gatt)
            emit(mapOf("type" to "discoveringServices", "device" to device(gatt.device), "role" to "central", "attempt" to attempt))
            logDebug("service discovery start attempt=${attempt ?: "unknown"} id=$id")
            if (!gatt.discoverServices()) {
                emitError("Android could not start service discovery for $id")
                gatt.disconnect()
            }
        } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            failGattWrites(id, "disconnected", "GATT disconnected for $id")
            cleanupCentral(id, gatt)
            emit(mapOf("type" to "disconnected", "device" to device(gatt.device), "role" to "central"))
        }
    }

    private fun handleServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        val id = gatt.device.address
        if (!isCurrentGatt(gatt)) {
            logDebug("Ignoring stale service discovery callback id=$id status=$status")
            gatt.close()
            return
        }
        logDebug("onServicesDiscovered id=$id status=$status")
        if (status != BluetoothGatt.GATT_SUCCESS) {
            readyClients.remove(id)
            emitError("Service discovery failed for $id (status $status)")
            gatt.disconnect()
            return
        }
        val service = gatt.getService(SERVICE)
        val rx = service?.getCharacteristic(RX)
        val tx = service?.getCharacteristic(TX)
        logDebug("GATT service=${service != null} rx=${rx != null} tx=${tx != null} id=$id")
        val rxWritable = rx?.let {
            (it.properties and (BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)) != 0
        } == true
        val txNotifiable = tx?.let {
            (it.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
        } == true
        if (service == null || rx == null || tx == null || !rxWritable || !txNotifiable) {
            readyClients.remove(id)
            emitError("Required SOS GATT service/RX write/TX notify properties are missing on $id")
            gatt.disconnect()
            return
        }
            emit(mapOf("type" to "serviceDiscovered", "device" to device(gatt.device), "role" to "central", "attempt" to connectionAttempts[id]))
            emit(mapOf("type" to "characteristicsDiscovered", "device" to device(gatt.device), "role" to "central", "attempt" to connectionAttempts[id]))
        if (!gatt.setCharacteristicNotification(tx, true)) {
            emitError("Could not enable TX notifications for $id")
            gatt.disconnect()
            return
        }
        val descriptor = tx.getDescriptor(CCCD)
        if (descriptor == null) {
            emitError("TX characteristic has no CCCD for $id")
            gatt.disconnect()
            return
        }
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        logDebug("Writing TX CCCD id=$id uuid=${descriptor.uuid}")
        if (!gatt.writeDescriptor(descriptor)) {
            emitError("Could not write TX notification descriptor for $id")
            gatt.disconnect()
        }
    }

    private fun handleDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        val id = gatt.device.address
        if (!isCurrentGatt(gatt)) {
            logDebug("Ignoring stale descriptor callback id=$id status=$status")
            gatt.close()
            return
        }
        logDebug("onDescriptorWrite id=$id uuid=${descriptor.uuid} status=$status")
        if (descriptor.uuid != CCCD) return
        if (status == BluetoothGatt.GATT_SUCCESS) {
            cancelSetupTimeout(id)
            readyClients.add(id)
            logDebug("transport ready id=$id")
            emit(mapOf("type" to "connected", "device" to device(gatt.device), "role" to "central", "attempt" to connectionAttempts[id]))
        } else {
            readyClients.remove(id)
            emitError("TX notification setup failed for $id (status $status)")
            gatt.disconnect()
        }
    }

    private fun isCurrentGatt(gatt: BluetoothGatt): Boolean = clients[gatt.device.address] === gatt

    private fun scheduleSetupTimeout(id: String, gatt: BluetoothGatt) {
        cancelSetupTimeout(id)
        val timeout = Runnable {
            if (isCurrentGatt(gatt) && !readyClients.contains(id)) {
                logError("GATT setup timeout id=$id attempt=${connectionAttempts[id] ?: "unknown"}")
                emitError("GATT setup timed out for $id")
                disconnectReasons[id] = "GATT setup timeout"
                gatt.disconnect()
            }
        }
        setupTimeouts[id] = timeout
        mainHandler.postDelayed(timeout, gattSetupTimeoutMs)
    }

    private fun cancelSetupTimeout(id: String) {
        setupTimeouts.remove(id)?.let(mainHandler::removeCallbacks)
    }

    private fun cleanupCentral(id: String, gatt: BluetoothGatt) {
        cancelSetupTimeout(id)
        readyClients.remove(id)
        if (clients[id] === gatt) clients.remove(id)
        disconnectReasons.remove(id)
        connectionAttempts.remove(id)
        gatt.close()
        logDebug("GATT cleanup complete id=$id")
    }

    private fun serverCallback(session: Int) = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            onMain {
                if (disposed || session != generation) return@onMain
                logDebug("onServiceAdded uuid=${service.uuid} status=$status")
                if (service.uuid != SERVICE) return@onMain
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    serverReady = true
                    if (advertisingResult != null) startAdvertisingNative()
                } else {
                    advertisingResult?.error("server_failed", "GATT service registration failed (status $status)", null)
                    advertisingResult = null
                    emitError("GATT service registration failed (status $status)")
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            onMain {
                if (disposed || session != generation) return@onMain
                val supported = characteristic.uuid == RX && !preparedWrite && offset == 0
                logDebug("onCharacteristicWriteRequest id=${device.address} uuid=${characteristic.uuid} requestId=$requestId prepared=$preparedWrite offset=$offset responseNeeded=$responseNeeded bytes=${value.size}")
                if (supported) {
                    emit(mapOf("type" to "data", "device" to device(device), "payload" to value, "role" to "peripheral"))
                }
                if (responseNeeded) {
                    server?.sendResponse(
                        device,
                        requestId,
                        if (supported) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,
                        offset,
                        null,
                    )
                }
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray,
        ) {
            val enabled = value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            val disabled = value.contentEquals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE)
            val supported = descriptor.uuid == CCCD &&
                descriptor.characteristic?.uuid == TX &&
                !preparedWrite && offset == 0 && (enabled || disabled)
            onMain {
                if (disposed || session != generation) return@onMain
                logDebug(
                    "onDescriptorWriteRequest id=${device.address} uuid=${descriptor.uuid} " +
                        "characteristic=${descriptor.characteristic?.uuid} requestId=$requestId " +
                        "prepared=$preparedWrite offset=$offset responseNeeded=$responseNeeded " +
                        "enabled=$enabled disabled=$disabled",
                )
                if (supported) {
                    if (enabled) {
                        val wasSubscribed = notificationClients.add(device.address)
                        if (wasSubscribed && serverClients.contains(device.address)) {
                            emit(mapOf("type" to "connected", "device" to device(device), "role" to "peripheral"))
                        }
                    } else {
                        notificationClients.remove(device.address)
                        clearNotificationSession(device.address, "TX notifications were disabled")
                        emit(mapOf("type" to "disconnected", "device" to device(device), "error" to "TX notifications disabled", "role" to "peripheral"))
                    }
                }
                if (responseNeeded) {
                    server?.sendResponse(
                        device,
                        requestId,
                        if (supported) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED,
                        offset,
                        null,
                    )
                }
                if (!supported) {
                    logError("Rejected unsupported CCCD write from ${device.address}")
                }
            }
        }

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            onMain {
                if (disposed || session != generation) return@onMain
                logDebug("server onConnectionStateChange id=${device.address} status=$status newState=$newState")
                if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                    serverClients.add(device.address)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    serverClients.remove(device.address)
                    notificationClients.remove(device.address)
                    clearNotificationSession(device.address, "Peripheral peer disconnected")
                    emit(mapOf("type" to "disconnected", "device" to device(device), "error" to if (status == BluetoothGatt.GATT_SUCCESS) null else "status $status", "role" to "peripheral"))
                } else if (status != BluetoothGatt.GATT_SUCCESS) {
                    serverClients.remove(device.address)
                    notificationClients.remove(device.address)
                    clearNotificationSession(device.address, "GATT server connection failed (status $status)")
                    emit(mapOf("type" to "error", "error" to "GATT server connection failed for ${device.address} (status $status)", "device" to device(device), "role" to "peripheral"))
                }
            }
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            onMain {
                if (disposed || session != generation) return@onMain
                logDebug("onNotificationSent id=${device.address} status=$status subscribed=${notificationClients.contains(device.address)}")
                val id = device.address
                val queue = notificationQueues[id]
                val pending = if (queue != null && !queue.isEmpty()) queue.removeFirst() else null
                notificationInFlight.remove(id)
                if (pending != null) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        pending.result.success(null)
                    } else {
                        pending.result.error("notification_failed", "TX notification failed for $id (status $status)", null)
                    }
                }
                flushPeripheralNotifications(id)
            }
        }
    }

    private fun clearNotificationSession(id: String, message: String) {
        notificationInFlight.remove(id)
        notificationQueues.remove(id)?.forEach {
            it.result.error("disconnected", message, null)
        }
    }
}

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
    private var advertisingActive = false
    private var advertiseCallback: AdvertiseCallback? = null
    private val clients = mutableMapOf<String, BluetoothGatt>()
    private val readyClients = mutableSetOf<String>()
    private val notificationClients = mutableSetOf<String>()
    private val serverClients = mutableSetOf<String>()
    private val disconnectReasons = mutableMapOf<String, String>()
    private data class PendingNotification(val value: ByteArray, val result: MethodChannel.Result)
    private val notificationQueues = mutableMapOf<String, ArrayDeque<PendingNotification>>()
    private val notificationInFlight = mutableSetOf<String>()
    private val maxPendingNotifications = 32
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var disposed = false

    fun register() {
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
        stopDiscovery()
        advertiser?.stopAdvertising(advertiseCallback)
        advertiser = null
        advertiseCallback = null
        advertisingActive = false
        advertisingResult?.error("disposed", "BLE transport was disposed", null)
        advertisingResult = null
        clients.values.toList().forEach { it.disconnect(); it.close() }
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
        server?.close()
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
        if (call.method == "requestPermissions") {
            requestPermissions()
            result.success(null)
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

    private fun requestPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        (context as? Activity)?.requestPermissions(permissions, 4101)
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

    private fun adapterState(): String = when {
        adapter == null -> "unsupported"
        !adapter.isEnabled -> "poweredOff"
        else -> "idle"
    }

    private fun ensureServer(result: MethodChannel.Result? = null) {
        if (server != null) {
            result?.success(null)
            return
        }
        server = manager.openGattServer(context, serverCallback)
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
        try {
            current.startScan(
                listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE)).build()),
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                scanCallback,
            )
            emit(mapOf("type" to "state", "state" to "discovering"))
            result.success(null)
        } catch (error: Exception) {
            result.error("scan_failed", error.message, null)
            emitError(error.message ?: "Could not start scanning")
        }
    }

    private fun stopDiscovery() {
        try { scanner?.stopScan(scanCallback) } catch (_: Exception) { }
        scanner = null
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
        clients[id] = gatt
        emit(mapOf("type" to "connecting", "device" to device(remote), "role" to "central"))
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
            it.disconnect()
            // Wait for onConnectionStateChange before closing this object.
        }
        readyClients.remove(id)
        notificationClients.remove(id)
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
        // Use a write-with-response so onCharacteristicWrite can confirm the
        // operation before the Dart layer reports it as accepted.
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        characteristic.value = bytes
        if (!gatt.writeCharacteristic(characteristic)) {
            result.error("write_failed", "Android rejected the GATT write", null)
            emitError("GATT write rejected for $id")
            return
        }
        result.success(null)
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

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            onMain {
                logDebug("onScanResult callbackType=$callbackType id=${result.device.address} rssi=${result.rssi}")
                emit(mapOf("type" to "deviceFound", "device" to device(result.device, result.rssi)))
            }
        }
        override fun onScanFailed(errorCode: Int) {
            onMain {
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
                logDebug("onCharacteristicWrite id=${gatt.device.address} uuid=${characteristic.uuid} status=$status")
                if (characteristic.uuid == RX) {
                    if (status == BluetoothGatt.GATT_SUCCESS) emit(mapOf("type" to "sendAccepted", "device" to device(gatt.device), "role" to "central"))
                    else emitError("GATT write callback failed for ${gatt.device.address} (status $status)")
                }
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            onMain { emitCharacteristicChanged(gatt, characteristic, characteristic.value) }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            onMain { emitCharacteristicChanged(gatt, characteristic, value) }
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
        val reason = disconnectReasons[id] ?: "remote_or_stack"
        logDebug("onConnectionStateChange id=$id status=$status newState=$newState reason=$reason")
        if (status != BluetoothGatt.GATT_SUCCESS) {
            readyClients.remove(id)
            if (clients[id] === gatt) clients.remove(id)
            gatt.close()
            disconnectReasons.remove(id)
            emit(mapOf("type" to "error", "error" to "GATT connection failed for $id (status $status)", "device" to device(gatt.device), "role" to "central"))
            emit(mapOf("type" to "disconnected", "device" to device(gatt.device), "error" to "status $status", "role" to "central"))
            return
        }
        if (newState == BluetoothProfile.STATE_CONNECTED) {
            emit(mapOf("type" to "discoveringServices", "device" to device(gatt.device), "role" to "central"))
            logDebug("discoverServices requested id=$id")
            if (!gatt.discoverServices()) {
                emitError("Android could not start service discovery for $id")
                gatt.disconnect()
            }
        } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            readyClients.remove(id)
            if (clients[id] === gatt) clients.remove(id)
            gatt.close()
            disconnectReasons.remove(id)
            emit(mapOf("type" to "disconnected", "device" to device(gatt.device), "role" to "central"))
        }
    }

    private fun handleServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        val id = gatt.device.address
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
            emit(mapOf("type" to "serviceDiscovered", "device" to device(gatt.device), "role" to "central"))
            emit(mapOf("type" to "characteristicsDiscovered", "device" to device(gatt.device), "role" to "central"))
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
        logDebug("onDescriptorWrite id=$id uuid=${descriptor.uuid} status=$status")
        if (descriptor.uuid != CCCD) return
        if (status == BluetoothGatt.GATT_SUCCESS) {
            readyClients.add(id)
            emit(mapOf("type" to "connected", "device" to device(gatt.device), "role" to "central"))
        } else {
            readyClients.remove(id)
            emitError("TX notification setup failed for $id (status $status)")
            gatt.disconnect()
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService) {
            onMain {
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

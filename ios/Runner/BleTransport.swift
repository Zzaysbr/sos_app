import CoreBluetooth
import Flutter
import Foundation

final class BleTransport: NSObject, FlutterStreamHandler, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
  static let service = CBUUID(string: "8B7F0001-6D3A-4C8B-9D21-5A7F2E110001")
  static let rx = CBUUID(string: "8B7F0002-6D3A-4C8B-9D21-5A7F2E110001")
  static let tx = CBUUID(string: "8B7F0003-6D3A-4C8B-9D21-5A7F2E110001")
  static let cccd = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")

  private var sink: FlutterEventSink?
  private var central: CBCentralManager!
  private var peripheral: CBPeripheralManager!
  private var discovered: [UUID: CBPeripheral] = [:]
  private var connected: [UUID: CBPeripheral] = [:]
  private var connecting = Set<UUID>()
  private var services = [UUID: CBService]()
  private var rxCharacteristics = [UUID: CBCharacteristic]()
  private var txCharacteristics = [UUID: CBCharacteristic]()
  private var notificationPending = Set<UUID>()
  private var ready = Set<UUID>()
  private var writeResults = [UUID: [FlutterResult]]()
  private var advertisingResult: FlutterResult?
  private var advertisingActive = false
  private var advertisedService: CBMutableService?
  private var advertisedRx: CBMutableCharacteristic?
  private var advertisedTx: CBMutableCharacteristic?
  private struct PendingPeripheralSend {
    let data: Data
    let result: FlutterResult
  }
  private var subscribedCentrals = [UUID: CBCentral]()
  private var pendingPeripheralSends = [UUID: [PendingPeripheralSend]]()
  private var pacedPeripheralSends = Set<UUID>()
  private let maxPendingPeripheralSends = 32
  // updateValue returning true only means CoreBluetooth accepted the local
  // notification. A short per-peer gap prevents multi-frame envelopes from
  // overrunning Android's receive path before it can emit frames to Dart.
  private let peripheralInterFrameDelay: TimeInterval = 0.012
  private var disconnectReasons = [UUID: String]()
  private var setupTimeouts = [UUID: DispatchWorkItem]()
  private var connectionAttempts = [UUID: Int]()
  private var nextConnectionAttempt = 0
  private var scanSession = 0
  private let gattSetupTimeout: TimeInterval = 15
  private var initializationResults = [FlutterResult]()
  private var initializationTimeout: DispatchWorkItem?
  private var disposed = false

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "sos_ble_transport/methods", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    FlutterEventChannel(name: "sos_ble_transport/events", binaryMessenger: messenger).setStreamHandler(self)
    central = CBCentralManager(delegate: self, queue: .main)
    peripheral = CBPeripheralManager(delegate: self, queue: .main)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    emit(["type": "centralState", "state": centralState()])
    emit(["type": "peripheralState", "state": peripheralState()])
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    trace("method \(call.method)")
    if call.method == "deviceIdentity" {
      let key = "sos.localDeviceIdentity.v1"
      let identity = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
      UserDefaults.standard.set(identity, forKey: key)
      result(identity)
      return
    }
    if disposed && (call.method == "requestPermissions" || call.method == "initialize") {
      // Replace managers; delegates from a retired session cannot reach the
      // current managers' state. Permission requests still precede initialize.
      central.delegate = nil
      peripheral.delegate = nil
      disposed = false
      central = CBCentralManager(delegate: self, queue: .main)
      peripheral = CBPeripheralManager(delegate: self, queue: .main)
    }
    if disposed && call.method != "dispose" {
      result(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil))
      return
    }
    switch call.method {
    case "initialize": initialize(result)
    case "requestPermissions": result(nil)
    case "startDiscovery": startDiscovery(result)
    case "stopDiscovery": central.stopScan(); emit(["type": "state", "state": centralState()]); result(nil)
    case "startAdvertising": startAdvertising(result)
    case "stopAdvertising": stopAdvertising(result)
    case "connect": connect(call, result: result)
    case "disconnect": disconnect(call, result: result)
    case "send": send(call, result: result)
    case "maxFrameBytes":
      guard let args = call.arguments as? [String: Any],
            let id = args["deviceId"] as? String, let uuid = UUID(uuidString: id) else {
        result(20); return
      }
      let role = args["role"] as? String
      if role == "peripheral" {
        result(peripheralFrameCapacity(subscribedCentrals[uuid]))
      } else if let peer = connected[uuid], ready.contains(uuid) {
        // The with-response limit may allow long/prepared writes, which the
        // Android server deliberately rejects. Use the single-packet bound
        // while retaining acknowledged .withResponse writes.
        result(max(20, min(512, peer.maximumWriteValueLength(for: .withoutResponse))))
      } else { result(20) }
    case "dispose": dispose(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func initialize(_ result: @escaping FlutterResult) {
    initializationResults.append(result)
    completeInitializationIfReady()
    if initializationResults.isEmpty || initializationTimeout != nil { return }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self else { return }
      let results = self.initializationResults
      self.initializationResults.removeAll()
      self.initializationTimeout = nil
      for result in results {
        result(FlutterError(code: "initialize_timeout", message: "Bluetooth readiness timed out. Try again after granting permission.", details: nil))
      }
    }
    initializationTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
  }

  private func completeInitializationIfReady() {
    guard !disposed, central.state != .unknown, central.state != .resetting,
          peripheral.state != .unknown, peripheral.state != .resetting else { return }
    initializationTimeout?.cancel()
    initializationTimeout = nil
    let results = initializationResults
    initializationResults.removeAll()
    results.forEach { $0(nil) }
  }

  private func invalidateCentralSessions(reason: String) {
    let ids = Set(connected.keys)
      .union(connecting)
      .union(ready)
      .union(writeResults.keys)
    guard !ids.isEmpty else { return }
    central.stopScan()
    for id in ids {
      if let peripheral = connected[id], peripheral.state != .disconnected {
        central.cancelPeripheralConnection(peripheral)
      }
      cancelSetupTimeout(for: id)
      if let results = writeResults.removeValue(forKey: id) {
        results.forEach {
          $0(FlutterError(code: "disconnected", message: reason, details: nil))
        }
      }
      connecting.remove(id)
      connected.removeValue(forKey: id)
      ready.remove(id)
      services.removeValue(forKey: id)
      notificationPending.remove(id)
      rxCharacteristics.removeValue(forKey: id)
      txCharacteristics.removeValue(forKey: id)
      disconnectReasons.removeValue(forKey: id)
      let attempt = connectionAttempts.removeValue(forKey: id)
      if let peripheral = discovered[id] {
        var event: [String: Any] = ["type": "disconnected", "device": device(peripheral), "error": reason, "role": "central"]
        if let attempt { event["attempt"] = attempt }
        emit(event)
      }
    }
    discovered.removeAll()
  }

  private func startDiscovery(_ result: @escaping FlutterResult) {
    guard central.state == .poweredOn else {
      let message = "iOS central Bluetooth is not powered on (state: \(centralState()))"
      emitError(message)
      result(FlutterError(code: "bluetooth_unavailable", message: message, details: nil))
      return
    }
    scanSession += 1
    let session = scanSession
    central.scanForPeripherals(withServices: [Self.service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    trace("startDiscovery accepted session=\(session) centralState=\(centralState()) service=\(Self.service.uuidString)")
    emit(["type": "state", "state": "discovering", "scanSession": session])
    result(nil)
  }

  private func startAdvertising(_ result: @escaping FlutterResult) {
    guard peripheral.state == .poweredOn else {
      let message = "iOS peripheral Bluetooth is not powered on (state: \(peripheralState()))"
      emitError(message)
      result(FlutterError(code: "bluetooth_unavailable", message: message, details: nil))
      return
    }
    if advertisingResult != nil || advertisingActive {
      result(FlutterError(code: "busy", message: "Advertising is already active or starting", details: nil))
      return
    }
    let rx = CBMutableCharacteristic(type: Self.rx, properties: [.write, .writeWithoutResponse], value: nil, permissions: [.writeable])
    let tx = CBMutableCharacteristic(type: Self.tx, properties: [.notify, .read], value: nil, permissions: [.readable])
    let service = CBMutableService(type: Self.service, primary: true)
    service.characteristics = [rx, tx]
    advertisedRx = rx
    advertisedTx = tx
    advertisedService = service
    advertisingResult = result
    peripheral.removeAllServices()
    peripheral.add(service)
    emit(["type": "state", "state": "startingAdvertising"])
  }

  private func stopAdvertising(_ result: @escaping FlutterResult) {
    trace("stopAdvertising requested")
    peripheral.stopAdvertising()
    advertisingActive = false
    advertisingResult?(FlutterError(code: "cancelled", message: "Advertising was stopped before it started", details: nil))
    advertisingResult = nil
    emit(["type": "state", "state": peripheralState()])
    result(nil)
  }

  private func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let id = (call.arguments as? [String: Any])?["deviceId"] as? String,
          let uuid = UUID(uuidString: id) else {
      result(FlutterError(code: "invalid_device", message: "Invalid device id", details: nil))
      return
    }
    guard central.state == .poweredOn else {
      result(FlutterError(code: "bluetooth_unavailable", message: "iOS central Bluetooth is not powered on", details: nil))
      return
    }
    guard let p = discovered[uuid] ?? central.retrievePeripherals(withIdentifiers: [uuid]).first else {
      result(FlutterError(code: "device_unavailable", message: "The device is no longer available", details: nil))
      return
    }
    if connecting.contains(uuid) || ready.contains(uuid) {
      result(FlutterError(code: "busy", message: "A connection already exists for this device", details: nil))
      return
    }
    discovered[uuid] = p
    connecting.insert(uuid)
    nextConnectionAttempt += 1
    connectionAttempts[uuid] = nextConnectionAttempt
    trace("connect attempt=\(nextConnectionAttempt) id=\(uuid.uuidString)")
    trace("connect requested id=\(uuid.uuidString)")
    p.delegate = self
    emit(["type": "connecting", "device": device(p), "role": "central", "attempt": nextConnectionAttempt])
    central.connect(p, options: nil)
    result(nil)
  }

  private func disconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let id = (call.arguments as? [String: Any])?["deviceId"] as? String,
          let uuid = UUID(uuidString: id) else { result(nil); return }
    // A Dart write deadline may be the only indication of a lost callback.
    // Retire local write readiness now; a late callback cannot send the rest
    // of the logical message or complete a fresh connection's write.
    ready.remove(uuid)
    if let results = writeResults.removeValue(forKey: uuid) {
      results.forEach { $0(FlutterError(code: "disconnected", message: "BLE write session retired", details: nil)) }
    }
    pendingPeripheralSends.removeValue(forKey: uuid)?.forEach {
      $0.result(FlutterError(code: "disconnected", message: "BLE write session retired", details: nil))
    }
    pacedPeripheralSends.remove(uuid)
    if subscribedCentrals.removeValue(forKey: uuid) != nil {
      emit(["type": "disconnected", "device": ["id": uuid.uuidString], "role": "peripheral"])
    }
    if let p = connected[uuid] ?? discovered[uuid] {
      disconnectReasons[uuid] = "flutter disconnect()"
      central.cancelPeripheralConnection(p)
    }
    result(nil)
  }

  private func send(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["deviceId"] as? String,
          let uuid = UUID(uuidString: id),
          let data = args["data"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "invalid_data", message: "deviceId and data are required", details: nil))
      return
    }
    let requestedRole = args["role"] as? String
    if requestedRole == "peripheral" ||
        (requestedRole == nil && (connected[uuid] == nil || !ready.contains(uuid)) && subscribedCentrals[uuid] != nil) {
      sendPeripheral(data.data, to: uuid, result: result)
      return
    }
    guard let p = connected[uuid],
          ready.contains(uuid),
          let characteristic = rxCharacteristics[uuid] else {
      result(FlutterError(code: "not_connected", message: "GATT session is not ready for this device", details: nil))
      return
    }
    writeResults[uuid, default: []].append(result)
    p.writeValue(data.data, for: characteristic, type: .withResponse)
  }

  private func peripheralFrameCapacity(_ central: CBCentral?) -> Int {
    max(20, min(512, central?.maximumUpdateValueLength ?? 20))
  }

  private func sendPeripheral(_ data: Data, to uuid: UUID, result: @escaping FlutterResult) {
    guard subscribedCentrals[uuid] != nil, advertisedTx != nil else {
      result(FlutterError(code: "not_ready", message: "Peripheral notification session is not ready", details: nil))
      return
    }
    var queue = pendingPeripheralSends[uuid] ?? []
    guard queue.count < maxPendingPeripheralSends else {
      result(FlutterError(code: "backpressure", message: "Too many pending peripheral notifications", details: nil))
      return
    }
    queue.append(PendingPeripheralSend(data: data, result: result))
    pendingPeripheralSends[uuid] = queue
    flushPeripheral(uuid)
  }

  private func flushPeripheral(_ uuid: UUID) {
    guard !pacedPeripheralSends.contains(uuid) else { return }
    guard let central = subscribedCentrals[uuid],
          let characteristic = advertisedTx,
          var queue = pendingPeripheralSends[uuid],
          !queue.isEmpty else { return }
    while !queue.isEmpty {
      let pending = queue[0]
      // Match the capacity advertised to Dart. A larger frame must never be
      // rejected here solely because the old unnegotiated fallback was20.
      let maximum = peripheralFrameCapacity(central)
      trace("TX notification bytes=\(pending.data.count) maximum=\(maximum) peer=\(uuid.uuidString)")
      guard pending.data.count <= maximum else {
        queue.removeFirst()
        pending.result(FlutterError(code: "notification_too_large", message: "TX frame exceeds negotiated ATT payload", details: pending.data.count))
        continue
      }
      guard peripheral.updateValue(
        pending.data,
        for: characteristic,
        onSubscribedCentrals: [central]
      ) else {
        pendingPeripheralSends[uuid] = queue
        return
      }
      queue.removeFirst()
      pending.result(nil)
      if queue.isEmpty {
        pendingPeripheralSends.removeValue(forKey: uuid)
      } else {
        pendingPeripheralSends[uuid] = queue
      }
      pacedPeripheralSends.insert(uuid)
      DispatchQueue.main.asyncAfter(deadline: .now() + peripheralInterFrameDelay) { [weak self] in
        guard let self else { return }
        self.pacedPeripheralSends.remove(uuid)
        guard !self.disposed else { return }
        self.flushPeripheral(uuid)
      }
      return
    }
    pendingPeripheralSends.removeValue(forKey: uuid)
  }

  private func dispose() {
    trace("dispose: stopping scan/advertising and cancelling \(connected.count) central connections")
    disposed = true
    initializationTimeout?.cancel()
    initializationTimeout = nil
    let initializing = initializationResults
    initializationResults.removeAll()
    initializing.forEach { $0(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil)) }
    for timeout in setupTimeouts.values { timeout.cancel() }
    setupTimeouts.removeAll()
    central.stopScan()
    peripheral.stopAdvertising()
    advertisingActive = false
    advertisingResult?(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil))
    advertisingResult = nil
    var retiring = discovered
    for (id, p) in connected { retiring[id] = p }
    for p in retiring.values {
      p.delegate = nil
      if p.state != .disconnected { central.cancelPeripheralConnection(p) }
    }
    for pending in pendingPeripheralSends.values.flatMap({ $0 }) {
      pending.result(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil))
    }
    pendingPeripheralSends.removeAll()
    pacedPeripheralSends.removeAll()
    subscribedCentrals.removeAll()
    for results in writeResults.values { results.forEach { $0(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil)) } }
    writeResults.removeAll()
    connected.removeAll(); discovered.removeAll(); connecting.removeAll(); services.removeAll()
    rxCharacteristics.removeAll(); txCharacteristics.removeAll(); notificationPending.removeAll(); ready.removeAll()
    advertisedService = nil; advertisedRx = nil; advertisedTx = nil
    disconnectReasons.removeAll()
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard !disposed, central === self.central else { return }
    completeInitializationIfReady()
    let state = centralState()
    trace("centralManagerDidUpdateState state=\(state)")
    if state == "poweredOff" || state == "unauthorized" ||
        state == "unsupported" || state == "resetting" {
      invalidateCentralSessions(reason: "Bluetooth adapter state is \(state)")
    }
    emit(["type": "centralState", "state": state])
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    guard !disposed, peripheral === self.peripheral else { return }
    completeInitializationIfReady()
    trace("peripheralManagerDidUpdateState state=\(peripheralState())")
    if peripheral.state != .poweredOn && peripheral.state != .unknown {
      advertisingActive = false
      subscribedCentrals.removeAll()
      pacedPeripheralSends.removeAll()
      for queue in pendingPeripheralSends.values {
        queue.forEach { $0.result(FlutterError(code: "bluetooth_unavailable", message: "Bluetooth peripheral state changed", details: nil)) }
      }
      pendingPeripheralSends.removeAll()
    }
    emit(["type": "peripheralState", "state": peripheralState()])
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    guard !disposed, peripheral === self.peripheral else { return }
    trace("didAdd service=\(service.uuid.uuidString) error=\(error?.localizedDescription ?? "none")")
    guard service.uuid == Self.service else { return }
    if let error {
      advertisingResult?(FlutterError(code: "advertise_failed", message: error.localizedDescription, details: nil))
      advertisingResult = nil
      advertisingActive = false
      emitError("iOS GATT service registration failed: \(error.localizedDescription)")
      return
    }
    peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.service]])
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    guard !disposed, peripheral === self.peripheral else { return }
    trace("didStartAdvertising error=\(error?.localizedDescription ?? "none")")
    if let error {
      advertisingResult?(FlutterError(code: "advertise_failed", message: error.localizedDescription, details: nil))
      advertisingResult = nil
      advertisingActive = false
      emitError("iOS advertising failed: \(error.localizedDescription)")
    } else {
      advertisingResult?(nil)
      advertisingResult = nil
      advertisingActive = true
      emit(["type": "state", "state": "advertising"])
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    guard !disposed, central === self.central else { return }
    trace("didDiscover session=\(scanSession) id=\(p.identifier.uuidString) name=\(p.name ?? "unknown") rssi=\(RSSI)")
    discovered[p.identifier] = p
    p.delegate = self
    emit(["type": "deviceFound", "device": device(p, rssi: RSSI), "scanSession": scanSession])
  }

  func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
    guard !disposed, central === self.central else { return }
    if let current = connected[p.identifier], current !== p {
      trace("ignoring stale didConnect id=\(p.identifier.uuidString)")
      central.cancelPeripheralConnection(p)
      return
    }
    trace("didConnect id=\(p.identifier.uuidString); starting service discovery")
    connecting.insert(p.identifier)
    connected[p.identifier] = p
    p.delegate = self
    scheduleSetupTimeout(for: p)
    emit(["type": "discoveringServices", "device": device(p), "role": "central", "attempt": connectionAttempts[p.identifier] ?? 0])
    p.discoverServices([Self.service])
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
    guard !disposed, central === self.central else { return }
    guard connected[p.identifier] == nil || connected[p.identifier] === p else {
      trace("ignoring stale didFailToConnect id=\(p.identifier.uuidString)")
      return
    }
    cancelSetupTimeout(for: p.identifier)
    connecting.remove(p.identifier)
    connected.removeValue(forKey: p.identifier)
    let attempt = connectionAttempts.removeValue(forKey: p.identifier)
    services.removeValue(forKey: p.identifier)
    notificationPending.remove(p.identifier)
    ready.remove(p.identifier)
    let message = "iOS failed to connect to \(p.identifier.uuidString): \(error?.localizedDescription ?? "unknown error")"
    trace("didFailToConnect id=\(p.identifier.uuidString) error=\(error?.localizedDescription ?? "none")")
    emitError(message)
    var event: [String: Any] = ["type": "disconnected", "device": device(p), "error": message, "role": "central"]
    if let attempt { event["attempt"] = attempt }
    emit(event)
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
    guard !disposed, central === self.central else { return }
    guard connected[p.identifier] === p ||
          (connected[p.identifier] == nil && connecting.contains(p.identifier)) else {
      trace("ignoring stale didDisconnectPeripheral id=\(p.identifier.uuidString)")
      return
    }
    cancelSetupTimeout(for: p.identifier)
    connecting.remove(p.identifier); connected.removeValue(forKey: p.identifier); ready.remove(p.identifier)
    let attempt = connectionAttempts.removeValue(forKey: p.identifier)
    services.removeValue(forKey: p.identifier)
    notificationPending.remove(p.identifier)
    rxCharacteristics.removeValue(forKey: p.identifier); txCharacteristics.removeValue(forKey: p.identifier)
    let message = error?.localizedDescription
    let reason = disconnectReasons.removeValue(forKey: p.identifier) ?? "remote_or_stack"
    trace("didDisconnectPeripheral id=\(p.identifier.uuidString) reason=\(reason) error=\(message ?? "none")")
    if let results = writeResults.removeValue(forKey: p.identifier) {
      results.forEach { $0(FlutterError(code: "disconnected", message: message ?? "Peripheral disconnected", details: nil)) }
    }
    var event: [String: Any] = ["type": "disconnected", "device": device(p), "role": "central"]
    if let attempt { event["attempt"] = attempt }
    if let message { event["error"] = message }
    emit(event)
  }

  func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
    guard !disposed, connected[p.identifier] === p else { return }
    guard connected[p.identifier] === p else {
      trace("ignoring stale didDiscoverServices id=\(p.identifier.uuidString)")
      return
    }
    trace("didDiscoverServices id=\(p.identifier.uuidString) error=\(error?.localizedDescription ?? "none") services=\(p.services?.map { $0.uuid.uuidString } ?? [])")
    guard error == nil else {
      failGATT(p, message: "Service discovery failed: \(error!.localizedDescription)"); return
    }
    guard let service = p.services?.first(where: { $0.uuid == Self.service }) else {
      failGATT(p, message: "Required SOS GATT service was not found"); return
    }
    services[p.identifier] = service
    trace("service matched id=\(p.identifier.uuidString) uuid=\(service.uuid.uuidString); discovering RX/TX")
    emit(["type": "serviceDiscovered", "device": device(p), "role": "central"])
    p.discoverCharacteristics([Self.rx, Self.tx], for: service)
  }

  func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard !disposed, connected[p.identifier] === p else { return }
    guard connected[p.identifier] === p else {
      trace("ignoring stale didDiscoverCharacteristics id=\(p.identifier.uuidString)")
      return
    }
    trace("didDiscoverCharacteristics id=\(p.identifier.uuidString) service=\(service.uuid.uuidString) error=\(error?.localizedDescription ?? "none") characteristics=\(service.characteristics?.map { $0.uuid.uuidString } ?? [])")
    guard error == nil else {
      failGATT(p, message: "Characteristic discovery failed: \(error!.localizedDescription)"); return
    }
    guard service.uuid == Self.service,
          let rx = service.characteristics?.first(where: { $0.uuid == Self.rx }),
          let tx = service.characteristics?.first(where: { $0.uuid == Self.tx }) else {
      failGATT(p, message: "Required RX/TX characteristics were not found"); return
    }
    rxCharacteristics[p.identifier] = rx
    txCharacteristics[p.identifier] = tx
    guard rx.properties.contains(.write) || rx.properties.contains(.writeWithoutResponse),
          tx.properties.contains(.notify) else {
      failGATT(p, message: "RX/TX properties are incompatible")
      return
    }
    notificationPending.insert(p.identifier)
    emit(["type": "characteristicsDiscovered", "device": device(p), "role": "central", "attempt": connectionAttempts[p.identifier] ?? 0])
    p.setNotifyValue(true, for: tx)
  }

  func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    guard !disposed, connected[p.identifier] === p else { return }
    guard connected[p.identifier] === p else {
      trace("ignoring stale didUpdateNotificationState id=\(p.identifier.uuidString)")
      return
    }
    trace("didUpdateNotificationState id=\(p.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) notifying=\(characteristic.isNotifying) error=\(error?.localizedDescription ?? "none")")
    guard characteristic.uuid == Self.tx else { return }
    notificationPending.remove(p.identifier)
    if let error {
      failGATT(p, message: "TX notification setup failed: \(error.localizedDescription)")
    } else if characteristic.isNotifying {
      ready.insert(p.identifier)
      cancelSetupTimeout(for: p.identifier)
      connecting.remove(p.identifier)
      trace("transport ready attempt=\(connectionAttempts[p.identifier] ?? 0) id=\(p.identifier.uuidString)")
      emit(["type": "connected", "device": device(p), "role": "central", "attempt": connectionAttempts[p.identifier] ?? 0])
    } else {
      failGATT(p, message: "TX notifications were not enabled")
    }
  }

  func peripheral(_ p: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    guard !disposed, connected[p.identifier] === p else { return }
    trace("didWriteValue id=\(p.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) error=\(error?.localizedDescription ?? "none")")
    guard characteristic.uuid == Self.rx else { return }
    let result = writeResults[p.identifier]?.removeFirst()
    if writeResults[p.identifier]?.isEmpty == true { writeResults.removeValue(forKey: p.identifier) }
    if let error {
      result?(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
      emitError("GATT write failed: \(error.localizedDescription)")
    } else {
      result?(nil)
      emit(["type": "sendAccepted", "device": device(p), "role": "central"])
    }
  }

  func peripheral(_ p: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard !disposed, connected[p.identifier] === p else { return }
    trace("didUpdateValue id=\(p.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) bytes=\(characteristic.value?.count ?? 0) error=\(error?.localizedDescription ?? "none")")
    guard characteristic.uuid == Self.tx else { return }
    guard error == nil, let data = characteristic.value else {
      emitError("TX notification read failed: \(error?.localizedDescription ?? "empty value")")
      return
    }
    emit(["type": "data", "device": device(p), "payload": FlutterStandardTypedData(bytes: data), "role": "central"])
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    guard !disposed, peripheral === self.peripheral else { return }
    trace("didReceiveWrite requests=\(requests.count)")
    for request in requests {
      let supported = request.characteristic.uuid == Self.rx && request.offset == 0
      if supported, let value = request.value {
        emit(["type": "data", "device": ["id": request.central.identifier.uuidString], "payload": FlutterStandardTypedData(bytes: value), "role": "peripheral"])
      }
      peripheral.respond(to: request, withResult: supported ? .success : .requestNotSupported)
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    guard !disposed, peripheral === self.peripheral else { return }
    guard characteristic.uuid == Self.tx else { return }
    subscribedCentrals[central.identifier] = central
    trace("didSubscribeTo id=\(central.identifier.uuidString) characteristic=\(characteristic.uuid.uuidString)")
    emit(["type": "connected", "device": ["id": central.identifier.uuidString], "role": "peripheral"])
    flushPeripheral(central.identifier)
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    guard !disposed, peripheral === self.peripheral else { return }
    guard characteristic.uuid == Self.tx else { return }
    let id = central.identifier
    subscribedCentrals.removeValue(forKey: id)
    pacedPeripheralSends.remove(id)
    pendingPeripheralSends.removeValue(forKey: id)?.forEach {
      $0.result(FlutterError(code: "disconnected", message: "Peripheral notification subscription ended", details: nil))
    }
    emit(["type": "disconnected", "device": ["id": id.uuidString], "error": "TX notifications disabled", "role": "peripheral"])
    trace("didUnsubscribeFrom id=\(id.uuidString) characteristic=\(characteristic.uuid.uuidString)")
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    guard !disposed, peripheral === self.peripheral else { return }
    for uuid in subscribedCentrals.keys {
      flushPeripheral(uuid)
    }
  }

  private func failGATT(_ p: CBPeripheral, message: String) {
    cancelSetupTimeout(for: p.identifier)
    connecting.remove(p.identifier); ready.remove(p.identifier)
    disconnectReasons[p.identifier] = "local GATT failure: \(message)"
    trace("failGATT id=\(p.identifier.uuidString) message=\(message)")
    emitError("\(message) [\(p.identifier.uuidString)]")
    central.cancelPeripheralConnection(p)
  }

  private func scheduleSetupTimeout(for p: CBPeripheral) {
    cancelSetupTimeout(for: p.identifier)
    let id = p.identifier
    let work = DispatchWorkItem { [weak self] in
      guard let self,
            self.connected[id] === p,
            !self.ready.contains(id) else { return }
      self.trace("GATT setup timeout attempt=\(self.connectionAttempts[id] ?? 0) id=\(id.uuidString)")
      self.failGATT(p, message: "GATT setup timed out")
    }
    setupTimeouts[id] = work
    DispatchQueue.main.asyncAfter(deadline: .now() + gattSetupTimeout, execute: work)
  }

  private func cancelSetupTimeout(for id: UUID) {
    setupTimeouts.removeValue(forKey: id)?.cancel()
  }

  private func centralState() -> String {
    switch central.state { case .poweredOn: return "poweredOn"; case .poweredOff: return "poweredOff"; case .unauthorized: return "unauthorized"; case .unsupported: return "unsupported"; case .resetting: return "resetting"; default: return "unknown" }
  }

  private func peripheralState() -> String {
    switch peripheral.state { case .poweredOn: return "poweredOn"; case .poweredOff: return "poweredOff"; case .unauthorized: return "unauthorized"; case .unsupported: return "unsupported"; case .resetting: return "resetting"; default: return "unknown" }
  }

  private func device(_ p: CBPeripheral, rssi: NSNumber? = nil) -> [String: Any] {
    ["id": p.identifier.uuidString, "name": p.name as Any, "rssi": rssi as Any]
  }

  private func trace(_ message: String) {
    NSLog("[BleTransport] t=%.3f %@", Date().timeIntervalSince1970, message)
  }

  private func emit(_ value: [String: Any]) { if !disposed { sink?(value) } }
  private func emitError(_ message: String) { emit(["type": "error", "error": message]) }
}

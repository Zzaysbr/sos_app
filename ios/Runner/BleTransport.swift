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
  private let maxPendingPeripheralSends = 32
  private var disconnectReasons = [UUID: String]()
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
    trace("method (call.method)")
    if disposed && call.method != "initialize" {
      result(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil))
      return
    }
    switch call.method {
    case "initialize": result(nil)
    case "requestPermissions": result(nil)
    case "startDiscovery": startDiscovery(result)
    case "stopDiscovery": central.stopScan(); emit(["type": "state", "state": centralState()]); result(nil)
    case "startAdvertising": startAdvertising(result)
    case "stopAdvertising": stopAdvertising(result)
    case "connect": connect(call, result: result)
    case "disconnect": disconnect(call, result: result)
    case "send": send(call, result: result)
    case "dispose": dispose(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func startDiscovery(_ result: @escaping FlutterResult) {
    guard central.state == .poweredOn else {
      let message = "iOS central Bluetooth is not powered on (state: \(centralState()))"
      emitError(message)
      result(FlutterError(code: "bluetooth_unavailable", message: message, details: nil))
      return
    }
    central.scanForPeripherals(withServices: [Self.service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    trace("startDiscovery accepted centralState=\(centralState()) service=\(Self.service.uuidString)")
    emit(["type": "state", "state": "discovering"])
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
    connecting.insert(uuid)
    trace("connect requested id=\(uuid.uuidString)")
    p.delegate = self
    emit(["type": "connecting", "device": device(p), "role": "central"])
    central.connect(p, options: nil)
    result(nil)
  }

  private func disconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let id = (call.arguments as? [String: Any])?["deviceId"] as? String,
          let uuid = UUID(uuidString: id), let p = connected[uuid] ?? discovered[uuid] else {
      result(nil)
      return
    }
    disconnectReasons[uuid] = "flutter disconnect()"
    trace("disconnect requested id=\(uuid.uuidString)")
    central.cancelPeripheralConnection(p)
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
    guard let central = subscribedCentrals[uuid],
          let characteristic = advertisedTx,
          var queue = pendingPeripheralSends[uuid],
          !queue.isEmpty else { return }
    while !queue.isEmpty {
      let pending = queue[0]
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
    }
    pendingPeripheralSends.removeValue(forKey: uuid)
  }

  private func dispose() {
    trace("dispose: stopping scan/advertising and cancelling \(connected.count) central connections")
    disposed = true
    central.stopScan()
    peripheral.stopAdvertising()
    advertisingActive = false
    advertisingResult?(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil))
    advertisingResult = nil
    for p in connected.values {
      disconnectReasons[p.identifier] = "transport dispose()"
      central.cancelPeripheralConnection(p)
    }
    for pending in pendingPeripheralSends.values.flatMap({ $0 }) {
      pending.result(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil))
    }
    pendingPeripheralSends.removeAll()
    subscribedCentrals.removeAll()
    for results in writeResults.values { results.forEach { $0(FlutterError(code: "disposed", message: "BLE transport was disposed", details: nil)) } }
    writeResults.removeAll()
    connected.removeAll(); discovered.removeAll(); connecting.removeAll(); services.removeAll()
    rxCharacteristics.removeAll(); txCharacteristics.removeAll(); notificationPending.removeAll(); ready.removeAll()
    advertisedService = nil; advertisedRx = nil; advertisedTx = nil
    disconnectReasons.removeAll()
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    trace("centralManagerDidUpdateState state=\(centralState())")
    emit(["type": "centralState", "state": centralState()])
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    trace("peripheralManagerDidUpdateState state=\(peripheralState())")
    emit(["type": "peripheralState", "state": peripheralState()])
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
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
    trace("didDiscover id=\(p.identifier.uuidString) name=\(p.name ?? "unknown") rssi=\(RSSI)")
    discovered[p.identifier] = p
    p.delegate = self
    emit(["type": "deviceFound", "device": device(p, rssi: RSSI)])
  }

  func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
    trace("didConnect id=\(p.identifier.uuidString); starting service discovery")
    connecting.insert(p.identifier)
    connected[p.identifier] = p
    p.delegate = self
    emit(["type": "discoveringServices", "device": device(p), "role": "central"])
    p.discoverServices([Self.service])
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
    connecting.remove(p.identifier)
    connected.removeValue(forKey: p.identifier)
    services.removeValue(forKey: p.identifier)
    notificationPending.remove(p.identifier)
    ready.remove(p.identifier)
    let message = "iOS failed to connect to \(p.identifier.uuidString): \(error?.localizedDescription ?? "unknown error")"
    trace("didFailToConnect id=\(p.identifier.uuidString) error=\(error?.localizedDescription ?? "none")")
    emitError(message)
      emit(["type": "disconnected", "device": device(p), "error": message, "role": "central"])
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
    connecting.remove(p.identifier); connected.removeValue(forKey: p.identifier); ready.remove(p.identifier)
    services.removeValue(forKey: p.identifier)
    notificationPending.remove(p.identifier)
    rxCharacteristics.removeValue(forKey: p.identifier); txCharacteristics.removeValue(forKey: p.identifier)
    let message = error?.localizedDescription
    let reason = disconnectReasons.removeValue(forKey: p.identifier) ?? "remote_or_stack"
    trace("didDisconnectPeripheral id=\(p.identifier.uuidString) reason=\(reason) error=\(message ?? "none")")
    if let results = writeResults.removeValue(forKey: p.identifier) {
      results.forEach { $0(FlutterError(code: "disconnected", message: message ?? "Peripheral disconnected", details: nil)) }
    }
    emit(["type": "disconnected", "device": device(p), "error": message as Any, "role": "central"])
  }

  func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
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
    emit(["type": "characteristicsDiscovered", "device": device(p), "role": "central"])
    p.setNotifyValue(true, for: tx)
  }

  func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    trace("didUpdateNotificationState id=\(p.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) notifying=\(characteristic.isNotifying) error=\(error?.localizedDescription ?? "none")")
    guard characteristic.uuid == Self.tx else { return }
    notificationPending.remove(p.identifier)
    if let error {
      failGATT(p, message: "TX notification setup failed: \(error.localizedDescription)")
    } else if characteristic.isNotifying {
      ready.insert(p.identifier)
      connecting.remove(p.identifier)
      emit(["type": "connected", "device": device(p), "role": "central"])
    } else {
      failGATT(p, message: "TX notifications were not enabled")
    }
  }

  func peripheral(_ p: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
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
    trace("didUpdateValue id=\(p.identifier.uuidString) uuid=\(characteristic.uuid.uuidString) bytes=\(characteristic.value?.count ?? 0) error=\(error?.localizedDescription ?? "none")")
    guard characteristic.uuid == Self.tx else { return }
    guard error == nil, let data = characteristic.value else {
      emitError("TX notification read failed: \(error?.localizedDescription ?? "empty value")")
      return
    }
    emit(["type": "data", "device": device(p), "payload": FlutterStandardTypedData(bytes: data), "role": "central"])
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
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
    guard characteristic.uuid == Self.tx else { return }
    subscribedCentrals[central.identifier] = central
    trace("didSubscribeTo id=\(central.identifier.uuidString) characteristic=\(characteristic.uuid.uuidString)")
    emit(["type": "connected", "device": ["id": central.identifier.uuidString], "role": "peripheral"])
    flushPeripheral(central.identifier)
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    guard characteristic.uuid == Self.tx else { return }
    let id = central.identifier
    subscribedCentrals.removeValue(forKey: id)
    pendingPeripheralSends.removeValue(forKey: id)?.forEach {
      $0.result(FlutterError(code: "disconnected", message: "Peripheral notification subscription ended", details: nil))
    }
    emit(["type": "disconnected", "device": ["id": id.uuidString], "error": "TX notifications disabled", "role": "peripheral"])
    trace("didUnsubscribeFrom id=\(id.uuidString) characteristic=\(characteristic.uuid.uuidString)")
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    for uuid in subscribedCentrals.keys {
      flushPeripheral(uuid)
    }
  }

  private func failGATT(_ p: CBPeripheral, message: String) {
    connecting.remove(p.identifier); ready.remove(p.identifier)
    disconnectReasons[p.identifier] = "local GATT failure: \(message)"
    trace("failGATT id=\(p.identifier.uuidString) message=\(message)")
    emitError("\(message) [\(p.identifier.uuidString)]")
    central.cancelPeripheralConnection(p)
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

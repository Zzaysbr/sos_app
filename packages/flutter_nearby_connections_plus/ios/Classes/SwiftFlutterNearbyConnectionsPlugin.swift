import Flutter
import UIKit
// import NearbyConnections
import SwiftyJSON

let SERVICE_TYPE = "flutter_nearby_connections"

let INVOKE_CHANGE_STATE_METHOD = "invoke_change_state_method"
let INVOKE_MESSAGE_RECEIVE_METHOD = "invoke_message_receive_method"

enum MethodCall: String {
    case initNearbyService = "init_nearby_service"
    case startAdvertisingPeer = "start_advertising_peer"
    case startBrowsingForPeers = "start_browsing_for_peers"
    case stopAdvertisingPeer = "stop_advertising_peer"
    case stopBrowsingForPeers = "stop_browsing_for_peers"
    case invitePeer = "invite_peer"
    case disconnectPeer = "disconnect_peer"
    case sendMessage = "send_message"
}

@objc(SwiftFlutterNearbyConnectionsPlugin)
public final class SwiftFlutterNearbyConnectionsPlugin: NSObject, FlutterPlugin {

    private let channel: FlutterMethodChannel

    struct DeviceJson {
        let deviceId: String
        let deviceName: String
        let state: Int

        func toDictionary() -> [String: Any] {
            [
                "deviceId": deviceId,
                "deviceName": deviceName,
                "state": state
            ]
        }
    }

    struct MessageJson {
        let deviceId: String
        let message: String

        func toDictionary() -> [String: Any] {
            [
                "deviceId": deviceId,
                "message": message
            ]
        }
    }

    public static func register(
        with registrar: FlutterPluginRegistrar
    ) {
        let channel = FlutterMethodChannel(
            name: "flutter_nearby_connections",
            binaryMessenger: registrar.messenger()
        )

        let instance = SwiftFlutterNearbyConnectionsPlugin(
            channel: channel
        )

        registrar.addMethodCallDelegate(
            instance,
            channel: channel
        )
    }

    public init(channel: FlutterMethodChannel) {
        self.channel = channel

        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stateChanged),
            name: MPCManager.Notifications.deviceDidChangeState,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(messageReceived),
            name: Device.messageReceivedNotification,
            object: nil
        )

        MPCManager.instance.deviceDidChange = { [weak self] in
            self?.stateChanged()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - State

    @objc
    private func stateChanged() {
        let devices = MPCManager.instance.devices.map {
            DeviceJson(
                deviceId: $0.endpointID,
                deviceName: $0.deviceName,
                state: $0.state
            ).toDictionary()
        }

        channel.invokeMethod(
            INVOKE_CHANGE_STATE_METHOD,
            arguments: JSON(devices).rawString()
        )
    }

    // MARK: - Message

    @objc
    private func messageReceived(
        notification: Notification
    ) {
        guard
            let userInfo = notification.userInfo,
            let data = userInfo["data"] as? Data,
            let endpointID = userInfo["from"] as? String
        else {
            return
        }

        guard
            let message = try? JSONSerialization.jsonObject(
                with: data,
                options: []
            ) as? [String: Any]
        else {
            print("Nearby: received invalid JSON payload")
            return
        }

        var payload = message
        payload["deviceId"] = endpointID

        channel.invokeMethod(
            INVOKE_MESSAGE_RECEIVE_METHOD,
            arguments: payload
        )
    }

    // MARK: - Method channel

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let method = MethodCall(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }

        switch method {

        case .initNearbyService:
            handleInit(call, result: result)

        case .startAdvertisingPeer:
            MPCManager.instance.startAdvertisingPeer()
            result(true)

        case .startBrowsingForPeers:
            MPCManager.instance.startBrowsingForPeers()
            result(true)

        case .stopAdvertisingPeer:
            MPCManager.instance.stopAdvertisingPeer()
            result(true)

        case .stopBrowsingForPeers:
            MPCManager.instance.stopBrowsingForPeers()
            result(true)

        case .invitePeer:
            handleInvite(call, result: result)

        case .disconnectPeer:
            handleDisconnect(call, result: result)

        case .sendMessage:
            handleSendMessage(call, result: result)
        }
    }

    // MARK: - Init

    private func handleInit(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard
            let arguments = call.arguments as? [String: Any]
        else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Expected argument dictionary",
                    details: nil
                )
            )
            return
        }

        let serviceType =
            arguments["serviceType"] as? String
            ?? SERVICE_TYPE

        let deviceName =
            arguments["deviceName"] as? String
            ?? UIDevice.current.name

        // Flutter package currently uses P2P_CLUSTER.
        // Nearby iOS equivalent is Strategy.cluster.
        MPCManager.instance.setup(
            serviceType: serviceType,
            deviceName: deviceName,
        )

        result(true)
    }

    // MARK: - Invite

    private func handleInvite(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard
            let arguments = call.arguments as? [String: Any],
            let deviceID = arguments["deviceId"] as? String,
            !deviceID.isEmpty
        else {
            result(
                FlutterError(
                    code: "INVALID_DEVICE_ID",
                    message: "Missing deviceId",
                    details: nil
                )
            )
            return
        }

        MPCManager.instance.invitePeer(
            deviceID: deviceID
        )

        result(true)
    }

    // MARK: - Disconnect

    private func handleDisconnect(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard
            let arguments = call.arguments as? [String: Any],
            let deviceID = arguments["deviceId"] as? String,
            !deviceID.isEmpty
        else {
            result(
                FlutterError(
                    code: "INVALID_DEVICE_ID",
                    message: "Missing deviceId",
                    details: nil
                )
            )
            return
        }

        MPCManager.instance.disconnectPeer(
            deviceID: deviceID
        )

        result(true)
    }

    // MARK: - Send

    private func handleSendMessage(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard
            let arguments = call.arguments as? [String: Any],
            let deviceID = arguments["deviceId"] as? String,
            !deviceID.isEmpty
        else {
            result(
                FlutterError(
                    code: "INVALID_DEVICE_ID",
                    message: "Missing deviceId",
                    details: nil
                )
            )
            return
        }

        guard
            let message = arguments["message"]
        else {
            result(
                FlutterError(
                    code: "INVALID_MESSAGE",
                    message: "Missing message",
                    details: nil
                )
            )
            return
        }

        guard
            JSONSerialization.isValidJSONObject(message)
        else {
            result(
                FlutterError(
                    code: "INVALID_MESSAGE",
                    message: "Message is not valid JSON",
                    details: nil
                )
            )
            return
        }

        do {
            let data = try JSONSerialization.data(
                withJSONObject: message,
                options: []
            )

            MPCManager.instance.send(
                data: data,
                to: deviceID
            ) { error in
                DispatchQueue.main.async {
                    if let error {
                        result(
                            FlutterError(
                                code: "SEND_FAILED",
                                message: error.localizedDescription,
                                details: nil
                            )
                        )
                    } else {
                        result(true)
                    }
                }
            }
        } catch {
            result(
                FlutterError(
                    code: "SERIALIZATION_FAILED",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }
}
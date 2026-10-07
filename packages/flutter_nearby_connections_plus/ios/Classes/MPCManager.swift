import Foundation
import UIKit

final class MPCManager: NSObject {
    struct Notifications {
        static let deviceDidChangeState =
            Notification.Name("deviceDidChangeState")
    }

    static let instance = MPCManager()

    private(set) var localDeviceName: String = ""
    private(set) var serviceType: String = ""

    var devices: [Device] = [] {
        didSet {
            deviceDidChange?()
        }
    }

    var deviceDidChange: (() -> Void)?

    private override init() {
        super.init()
    }

    func setup(
        serviceType: String,
        deviceName: String,
        strategy: Any? = nil
    ) {
        self.serviceType = serviceType
        self.localDeviceName = deviceName.isEmpty
            ? UIDevice.current.name
            : deviceName
    }

    func startAdvertisingPeer() {
        print("Nearby iOS: temporarily disabled")
    }

    func stopAdvertisingPeer() {
        print("Nearby iOS: temporarily disabled")
    }

    func startBrowsingForPeers() {
        print("Nearby iOS: temporarily disabled")
    }

    func stopBrowsingForPeers() {
        print("Nearby iOS: temporarily disabled")
    }

    func invitePeer(deviceID: String) {
        print("Nearby iOS: temporarily disabled")
    }

    func disconnectPeer(deviceID: String) {
        print("Nearby iOS: temporarily disabled")
    }

    func send(
        data: Data,
        to deviceID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        let error = NSError(
            domain: "MPCManager",
            code: 503,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Nearby Connections is temporarily disabled on iOS"
            ]
        )

        completion?(error)
    }
}
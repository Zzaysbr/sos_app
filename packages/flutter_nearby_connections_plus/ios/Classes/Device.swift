import Foundation

final class Device: NSObject {
    let endpointID: String
    let deviceName: String

    /// 0 = disconnected
    /// 1 = connecting
    /// 2 = connected
    /// 3 = rejected
    var state: Int = 0

    init(endpointID: String, deviceName: String) {
        self.endpointID = endpointID
        self.deviceName = deviceName
        super.init()
    }

    static let messageReceivedNotification =
        Notification.Name("DeviceDidReceiveMessage")

    func updateState(_ newState: Int) {
        state = newState

        NotificationCenter.default.post(
            name: MPCManager.Notifications.deviceDidChangeState,
            object: self
        )
    }
}
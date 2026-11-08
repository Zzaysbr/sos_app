import Flutter
import UIKit
import UserNotifications
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bleTransport: BleTransport?
  private var pendingChatNotifications = Set<String>()
  private var notificationChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(name: "sos_app/external_links", binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "open", let value = call.arguments as? String,
              let url = URL(string: value), url.scheme == "https",
              let host = url.host, ["www.openstreetmap.org", "www.geoapify.com"].contains(host) else {
          result(FlutterError(code: "invalid_link", message: "Unsupported attribution link", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          if success { result(nil) }
          else { result(FlutterError(code: "open_failed", message: "Unable to open attribution", details: nil)) }
        }
      }
    FlutterMethodChannel(name: "sos_app/preferences", binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setMethodCallHandler { call, result in
        switch call.method {
        case "getPreferredRole":
          result(UserDefaults.standard.string(forKey: "sos.preferredRole.v1"))
        case "setPreferredRole":
          guard let role = call.arguments as? String,
                ["needHelp", "rescue"].contains(role) else {
            result(FlutterError(code: "invalid_role", message: "Unsupported role preference", details: nil))
            return
          }
          UserDefaults.standard.set(role, forKey: "sos.preferredRole.v1")
          result(nil)
        case "getPreferredLanguage":
          result(UserDefaults.standard.string(forKey: "sos.preferredLanguage.v1"))
        case "setPreferredLanguage":
          guard let language = call.arguments as? String,
                ["en", "th"].contains(language) else {
            result(FlutterError(code: "invalid_language", message: "Unsupported language preference", details: nil))
            return
          }
          UserDefaults.standard.set(language, forKey: "sos.preferredLanguage.v1")
          result(nil)
        case "getRelayParticipationEnabled":
          result(UserDefaults.standard.bool(forKey: "sos.relayParticipationEnabled.v1"))
        case "setRelayParticipationEnabled":
          guard let enabled = call.arguments as? Bool else {
            result(FlutterError(code: "invalid_relay_preference", message: "Relay preference must be boolean", details: nil))
            return
          }
          UserDefaults.standard.set(enabled, forKey: "sos.relayParticipationEnabled.v1")
          result(nil)
        case "getEmergencyConsent":
          result([
            "configured": UserDefaults.standard.bool(forKey: "sos.emergencyConsentConfigured.v1"),
            "allowPublicRelay": UserDefaults.standard.bool(forKey: "sos.emergencyPublicRelay.v1"),
            "shareLocation": UserDefaults.standard.bool(forKey: "sos.emergencyRelayLocation.v1"),
            "allowVoluntaryRescue": UserDefaults.standard.bool(forKey: "sos.emergencyVoluntaryRescue.v1"),
          ])
        case "setEmergencyConsent":
          guard let value = call.arguments as? [String: Any],
                let configured = value["configured"] as? Bool,
                let allowPublicRelay = value["allowPublicRelay"] as? Bool,
                let shareLocation = value["shareLocation"] as? Bool,
                !shareLocation || allowPublicRelay else {
            result(FlutterError(code: "invalid_emergency_consent", message: "Emergency consent is invalid", details: nil))
            return
          }
          UserDefaults.standard.set(configured, forKey: "sos.emergencyConsentConfigured.v1")
          UserDefaults.standard.set(allowPublicRelay, forKey: "sos.emergencyPublicRelay.v1")
          UserDefaults.standard.set(shareLocation, forKey: "sos.emergencyRelayLocation.v1")
          UserDefaults.standard.set((value["allowVoluntaryRescue"] as? Bool ?? false) && allowPublicRelay, forKey: "sos.emergencyVoluntaryRescue.v1")
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    bleTransport = BleTransport(messenger: engineBridge.applicationRegistrar.messenger())
    notificationChannel = FlutterMethodChannel(name: "sos_app/background", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    notificationChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setBleBackground":
        // CoreBluetooth background modes allow event-driven work. This is not
        // an exemption from suspension or permission/force-quit restrictions.
        result(call.arguments as? Bool == true)
      case "requestNotifications":
        guard UIApplication.shared.applicationState == .active else { result(false); return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
          DispatchQueue.main.async { result(allowed) }
        }
      case "notifyChat": self?.notifyChat(call, result: result)
      default: result(FlutterMethodNotImplemented)
      }
    }

  }
  private func notifyChat(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let owner = args["ownerId"] as? String, !owner.isEmpty, owner.count < 512,
          let message = args["messageId"] as? String, !message.isEmpty, message.count < 512,
          let text = args["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 2000 else {
      result(FlutterError(code: "invalid_notification", message: "Invalid chat notification", details: nil)); return
    }
    let digest = SHA256.hash(data: Data((owner + "\0" + message).utf8)).map { String(format: "%02x", $0) }.joined()
    let defaults = UserDefaults.standard
    var receipts = defaults.dictionary(forKey: "sos.chatNotifications.v1") as? [String: Double] ?? [:]
    if receipts[digest] != nil || pendingChatNotifications.contains(digest) { result(nil); return }
    pendingChatNotifications.insert(digest)
    let remember = {
      self.pendingChatNotifications.remove(digest)
      receipts = defaults.dictionary(forKey: "sos.chatNotifications.v1") as? [String: Double] ?? [:]
      if receipts.count >= 2048 {
        for key in receipts.sorted(by: { $0.value < $1.value }).prefix(256).map({ $0.key }) { receipts.removeValue(forKey: key) }
      }
      receipts[digest] = Date().timeIntervalSince1970
      defaults.set(receipts, forKey: "sos.chatNotifications.v1")
    }
    // In-app Chat already observes the durable row. Only alert outside the app.
    if UIApplication.shared.applicationState == .active { remember(); result(nil); return }
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
        DispatchQueue.main.async { self.pendingChatNotifications.remove(digest); result(nil) }; return
      }
      let content = UNMutableNotificationContent()
      content.title = "Emergency"
      content.body = text
      content.sound = .default
      // A stable ID coalesces a retry after OS acceptance but before receipt save.
      center.add(UNNotificationRequest(identifier: "chat-" + digest, content: content, trigger: nil)) { error in
        DispatchQueue.main.async {
          if error == nil { remember(); result(nil) }
          else { self.pendingChatNotifications.remove(digest); result(FlutterError(code: "notification_failed", message: "Notification was not accepted", details: nil)) }
        }
      }
    }
  }

}

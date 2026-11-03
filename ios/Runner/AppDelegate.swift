import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bleTransport: BleTransport?
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
  }
}

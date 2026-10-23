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
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    bleTransport = BleTransport(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

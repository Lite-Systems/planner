import Cocoa
import FlutterMacOS
import WidgetKit

final class PlannerWidgetChannel {
  private let channel: FlutterMethodChannel
  private let writeQueue = DispatchQueue(label: "com.litesystems.smartplanner.widget")

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "smart_planner/macos_widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "prepare":
        guard PlannerWidgetSnapshot.containerURL() != nil else {
          result(FlutterError(code: "widget_app_group_unavailable",
            message: "Sign Runner and PlannerWidget with the same Apple team and App Groups capability.",
            details: nil))
          return
        }
        let extensionURL = Bundle.main.builtInPlugInsURL?
          .appendingPathComponent("PlannerWidget.appex")
        guard let extensionURL = extensionURL,
              FileManager.default.fileExists(atPath: extensionURL.path) else {
          result(FlutterError(code: "widget_extension_missing",
            message: "Rebuild the macOS app with the PlannerWidget extension.", details: nil))
          return
        }
        result(nil)
      case "updateSnapshot":
        guard let json = call.arguments as? String,
              let data = json.data(using: .utf8),
              (try? JSONDecoder().decode(PlannerWidgetSnapshot.self, from: data)) != nil else {
          result(FlutterError(code: "invalid_snapshot", message: "Invalid widget data.", details: nil))
          return
        }
        guard let container = PlannerWidgetSnapshot.containerURL() else {
          result(FlutterError(code: "widget_app_group_unavailable",
            message: "A signed macOS build is required for widget sharing.", details: nil))
          return
        }
        // File IO runs outside the platform/UI thread; atomic replacement keeps
        // WidgetKit from reading a partially written snapshot.
        self.writeQueue.async {
          do {
            try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            try data.write(to: container.appendingPathComponent("planner-widget.json"), options: .atomic)
            DispatchQueue.main.async {
              WidgetCenter.shared.reloadTimelines(ofKind: "SmartPlannerWidget")
              result(nil)
            }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "widget_write_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "openSettings":
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension"),
              NSWorkspace.shared.open(url) else {
          result(FlutterError(code: "settings_unavailable",
            message: "Open System Settings > Desktop & Dock > Widgets.", details: nil))
          return
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

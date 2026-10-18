import Foundation

/// Checks the same App Group lookup used when the widget switch is enabled.
@main
struct WidgetReadinessProbe {
  static func main() {
    guard CommandLine.arguments.count == 2,
          let bundle = Bundle(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
      print("Usage: WidgetReadinessProbe /path/to/planner.app")
      exit(2)
    }
    guard let container = PlannerWidgetSnapshot.containerURL(bundle: bundle) else {
      print("FAIL: widget_app_group_unavailable (the widget prepare check rejects this build)")
      exit(1)
    }
    // Use a unique temporary file, never the application's widget snapshot.
    let probe = container.appendingPathComponent(".widget-readiness-\(UUID().uuidString).json")
    do {
      defer { try? FileManager.default.removeItem(at: probe) }
      try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
      try JSONEncoder().encode(PlannerWidgetSnapshot.empty).write(to: probe, options: .atomic)
      _ = try JSONDecoder().decode(PlannerWidgetSnapshot.self, from: Data(contentsOf: probe))
      print("PASS: widget App Group lookup and atomic snapshot IO are available")
    } catch {
      print("FAIL: widget snapshot IO failed: \(error.localizedDescription)")
      exit(1)
    }
  }
}

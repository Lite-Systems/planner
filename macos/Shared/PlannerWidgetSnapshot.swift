import Foundation

struct PlannerWidgetTask: Codable {
  let name: String
}

struct PlannerWidgetSnapshot: Codable {
  let enabled: Bool
  let protected: Bool
  let total: Int?
  let completed: Int?
  let running: Int?
  let tasks: [PlannerWidgetTask]?

  static let empty = PlannerWidgetSnapshot(
    enabled: false, protected: false, total: nil,
    completed: nil, running: nil, tasks: nil
  )

  static func containerURL(bundle: Bundle = .main) -> URL? {
    guard let identifier = bundle.object(forInfoDictionaryKey: "PlannerAppGroup") as? String,
          !identifier.isEmpty, !identifier.contains("$("),
          identifier != "com.litesystems.smartplanner" else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
  }

  static func load() -> PlannerWidgetSnapshot {
    guard let url = containerURL()?.appendingPathComponent("planner-widget.json"),
          let data = try? Data(contentsOf: url),
          let snapshot = try? JSONDecoder().decode(PlannerWidgetSnapshot.self, from: data)
    else { return .empty }
    return snapshot
  }
}

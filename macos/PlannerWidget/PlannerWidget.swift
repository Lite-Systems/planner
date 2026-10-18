import SwiftUI
import WidgetKit

struct PlannerEntry: TimelineEntry {
  let date: Date
  let snapshot: PlannerWidgetSnapshot
}

struct PlannerTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> PlannerEntry {
    PlannerEntry(date: Date(), snapshot: PlannerWidgetSnapshot(
      enabled: true, protected: false, total: 8, completed: 5, running: 1,
      tasks: [PlannerWidgetTask(name: "Plan your next task")]
    ))
  }

  func getSnapshot(in context: Context, completion: @escaping (PlannerEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context)
      : PlannerEntry(date: Date(), snapshot: .load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PlannerEntry>) -> Void) {
    // Mutations trigger reloadTimelines from the app. Periodic reads also recover
    // from a missed reload without a background process or database polling.
    completion(Timeline(entries: [PlannerEntry(date: Date(), snapshot: .load())],
      policy: .after(Date().addingTimeInterval(30 * 60))))
  }
}

struct PlannerWidgetView: View {
  let entry: PlannerEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let snapshot = entry.snapshot
    VStack(alignment: .leading, spacing: 10) {
      Label("Smart Planner", systemImage: "checklist")
        .font(.headline)
        .foregroundStyle(.orange)
      if !snapshot.enabled {
        Text("Enable the macOS widget in Planner Settings.")
          .font(.caption).foregroundStyle(.secondary)
      } else if snapshot.protected {
        Label("Open Planner to view your tasks", systemImage: "lock.fill")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        let total = max(0, snapshot.total ?? 0)
        let completed = min(total, max(0, snapshot.completed ?? 0))
        HStack(alignment: .top, spacing: 14) {
          VStack(alignment: .leading, spacing: 6) {
            Text("\(max(0, total - completed))")
              .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("tasks remaining").font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(completed), total: Double(max(total, 1)))
              .tint(.orange)
            if (snapshot.running ?? 0) > 0 {
              Label("\(snapshot.running ?? 0) active timers", systemImage: "timer")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          if family == .systemMedium {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array((snapshot.tasks ?? []).prefix(3).enumerated()), id: \.offset) { _, task in
                Label(task.name, systemImage: "circle")
                  .font(.caption).lineLimit(2)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .containerBackground(.background, for: .widget)
  }
}

@main
struct SmartPlannerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SmartPlannerWidget", provider: PlannerTimelineProvider()) { entry in
      PlannerWidgetView(entry: entry)
    }
    .configurationDisplayName("Smart Planner")
    .description("Task progress and upcoming work at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

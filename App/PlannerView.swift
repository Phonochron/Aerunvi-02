import StudyPlannerCore
import SwiftUI

struct PlannerView: View {
  @Bindable var store: PlannerStore
  @State private var editing = false
  @State private var preview: SchedulerReport?
  @State private var previewInput: PlannerInput?
  @State private var previewRevision: Int?
  @State private var error: String?

  var body: some View {
    TabView {
      NavigationStack {
        List {
          Section("Your workload") {
            LabeledContent("Courses", value: "\(store.state.input.courses.count)")
            LabeledContent(
              "Pending tasks", value: "\(store.state.input.tasks.filter { !$0.isComplete }.count)")
            Button("Manage tasks and availability", systemImage: "square.and.pencil") {
              editing = true
            }
          }
          Section("Generate a plan") {
            Button("Generate 14-day preview", systemImage: "calendar.badge.plus") {
              previewInput = store.state.input
              previewRevision = store.state.revision
              preview = Scheduler.generate(store.state.input, context: store.planningContext())
            }
            Text(
              "Generate creates a preview. Your approved schedule changes only when you approve it."
            ).font(.caption)
          }
          if let preview, let previewInput {
            Section("Preview actions") {
              Button("Approve this plan") {
                do {
                  guard previewRevision == store.state.revision else {
                    throw ScenarioError.baselineChanged
                  }
                  try store.approve(preview)
                  self.preview = nil
                } catch { self.error = error.localizedDescription }
              }.disabled(preview.status == .invalidInput)
              Button("Discard preview", role: .cancel) { self.preview = nil }
            }
            ReportView(report: preview, input: previewInput)
          } else if let plan = store.state.approvedPlan {
            if plan.isStale(input: store.state.input, timeZoneID: store.state.timeZoneID)
              || plan.report.context.start < Calendar.current.startOfDay(for: .now)
            {
              Section {
                Label(
                  "This schedule is outdated. Generate a new preview.",
                  systemImage: "clock.badge.exclamationmark")
              }
            }
            ReportView(report: plan.report, input: plan.input)
          } else {
            Section {
              Text("Add courses, tasks and weekly study windows, then generate your first plan.")
            }
          }
        }.navigationTitle("Study Planner")
      }.tabItem { Label("Planner", systemImage: "calendar") }
      ScenarioView(store: store).tabItem { Label("What-if", systemImage: "arrow.triangle.branch") }
      NavigationStack {
        Form {
          Section("Planning time zone") {
            Picker(
              "Time zone",
              selection: Binding(
                get: { store.state.timeZoneID },
                set: { zone in
                  do { try store.setTimeZone(zone) } catch {
                    self.error = error.localizedDescription
                  }
                })
            ) {
              ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
            }
          }
          Section("Scheduling rules") {
            Text(
              "14-day horizon · earliest deadline first · priority breaks deadline ties · sessions of 30–60 minutes."
            )
            Text(
              "Work shorter than 30 minutes remains unscheduled. This heuristic does not guarantee an optimal plan."
            )
          }
          Section("Privacy") {
            Text("Saved locally on this device. No account or cloud service is required.")
          }
        }.navigationTitle("Settings")
      }.tabItem { Label("Settings", systemImage: "gearshape") }
    }
    .environment(\.timeZone, TimeZone(identifier: store.state.timeZoneID) ?? .current)
    .sheet(isPresented: $editing) {
      InputEditor(input: store.state.input) { try store.save(input: $0) }
    }
    .alert(
      "Unable to update planner",
      isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK") { error = nil }
    } message: {
      Text(error ?? "")
    }
  }
}

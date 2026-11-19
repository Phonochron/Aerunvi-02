import StudyPlannerCore
import SwiftUI

struct ScenarioView: View {
  @Bindable var store: PlannerStore
  @State private var draft: ScenarioDraft?
  @State private var editing = false
  @State private var error: String?

  var body: some View {
    NavigationStack {
      List {
        if let draft {
          let proposed = draft.proposed
          Section("Compare at the same planning start") {
            metric("Available minutes", draft.baseline.availableMinutes, proposed.availableMinutes)
            metric("Required minutes", draft.baseline.requiredMinutes, proposed.requiredMinutes)
            metric("Scheduled minutes", draft.baseline.scheduledMinutes, proposed.scheduledMinutes)
            metric(
              "Unscheduled minutes", draft.baseline.unscheduledMinutes, proposed.unscheduledMinutes)
            metric(
              "Fully scheduled tasks", draft.baseline.fullyScheduledTasks,
              proposed.fullyScheduledTasks)
            metric("Tasks at risk", draft.baseline.atRiskTasks, proposed.atRiskTasks)
            LabeledContent("Sessions added or removed", value: "\(draft.changedSessions)")
            Text(
              "Baseline: \(draft.baseline.status.rawValue) → Proposed: \(proposed.status.rawValue)"
            ).font(.caption)
          }
          Section("Draft actions") {
            Button("Edit scenario") { editing = true }
            Button("Apply scenario") {
              do {
                try store.apply(draft)
                self.draft = nil
              } catch { self.error = error.localizedDescription }
            }.disabled(
              proposed.status == .invalidInput || draft.baselineRevision != store.state.revision)
            Button("Discard scenario", role: .cancel) { self.draft = nil }
            if draft.baselineRevision != store.state.revision {
              Text("Baseline changed. Discard and start a new scenario.")
            }
          }
          ReportView(report: proposed, input: draft.input)
        } else {
          Section {
            Text(
              "Explore changes to workload, deadlines and availability without changing saved data."
            )
            Button("Create scenario", systemImage: "plus") {
              draft = ScenarioDraft(state: store.state, context: store.planningContext())
            }
          }
        }
      }.navigationTitle("What-if")
        .sheet(isPresented: $editing) {
          if let draft {
            InputEditor(input: draft.input) { input in
              let errors = Scheduler.validate(input, context: draft.context)
              guard errors.isEmpty else {
                throw StoreError.validation(errors.joined(separator: "\n"))
              }
              self.draft?.input = input
            }
          }
        }
        .alert(
          "Unable to apply",
          isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
          Button("OK") { error = nil }
        } message: {
          Text(error ?? "")
        }
    }
  }

  private func metric(_ title: String, _ baseline: Int, _ proposed: Int) -> some View {
    LabeledContent(title, value: "\(baseline) → \(proposed)")
  }
}

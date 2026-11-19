import StudyPlannerCore
import SwiftUI

struct ReportView: View {
  let report: SchedulerReport
  let input: PlannerInput

  var body: some View {
    Section("Feasibility") {
      Label(
        report.status.rawValue,
        systemImage: report.status == .fullyScheduled
          ? "checkmark.circle" : "exclamationmark.triangle")
      LabeledContent("Available", value: "\(report.availableMinutes) min")
      LabeledContent("Required within horizon", value: "\(report.requiredMinutes) min")
      LabeledContent("Scheduled", value: "\(report.scheduledMinutes) min")
      LabeledContent("Unscheduled", value: "\(report.unscheduledMinutes) min")
      LabeledContent("Fully scheduled tasks", value: "\(report.fullyScheduledTasks)")
      LabeledContent("Tasks at risk", value: "\(report.atRiskTasks)")
      LabeledContent("Outside horizon", value: "\(report.outsideHorizonTasks)")
      LabeledContent("Time zone", value: report.context.timeZoneID)
      Text("\(display(report.context.start)) – \(display(report.horizonEnd))").font(.caption)
    }
    if !report.explanations.isEmpty {
      Section("Explanation") {
        ForEach(Array(report.explanations.enumerated()), id: \.offset) { _, text in Text(text) }
      }
    }
    Section("Study sessions") {
      if report.sessions.isEmpty { Text("No study sessions.").foregroundStyle(.secondary) }
      ForEach(report.sessions) { session in
        VStack(alignment: .leading, spacing: 4) {
          Text(input.tasks.first { $0.id == session.taskID }?.title ?? "Removed task").font(
            .headline)
          Text(display(session.start))
          Text(
            "Until \(display(session.end)) · \(session.minutes) min"
          ).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
      }
    }
  }

  private func display(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    formatter.timeZone = TimeZone(identifier: report.context.timeZoneID)
    return formatter.string(from: date)
  }
}

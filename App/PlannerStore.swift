import Foundation
import Observation
import StudyPlannerCore
import SwiftData

@Model
final class StoredPlanner {
  var schemaVersion: Int = 1
  var payload: Data
  init(payload: Data) { self.payload = payload }
}

/// One versioned snapshot keeps input, approved schedule and revision in the same save.
@MainActor @Observable
final class PlannerStore {
  private(set) var state: PlannerState
  private let context: ModelContext
  private let record: StoredPlanner

  init(container: ModelContainer) throws {
    context = ModelContext(container)
    context.autosaveEnabled = false
    if let existing = try context.fetch(FetchDescriptor<StoredPlanner>()).first {
      guard existing.schemaVersion == 1 else {
        throw StoreError.validation(
          "Unsupported saved-data version. Update the app before opening this planner.")
      }
      record = existing
      state = try JSONDecoder().decode(PlannerState.self, from: existing.payload)
    } else {
      state = PlannerState()
      record = StoredPlanner(payload: try JSONEncoder().encode(state))
      context.insert(record)
      try context.save()
    }
  }

  func planningContext() -> PlanningContext {
    PlanningContext(start: .now, timeZoneID: state.timeZoneID)
  }

  func save(input: PlannerInput) throws {
    let errors = Scheduler.validate(input, context: planningContext())
    guard errors.isEmpty else { throw StoreError.validation(errors.joined(separator: "\n")) }
    var updated = state
    updated.input = input
    updated.revision += 1
    try commit(updated)
  }

  func approve(_ report: SchedulerReport) throws {
    guard report.status != .invalidInput else {
      throw StoreError.validation(report.explanations.joined(separator: "\n"))
    }
    var updated = state
    updated.approvedPlan = ApprovedPlan(
      input: state.input, report: report, revision: state.revision)
    try commit(updated)
  }

  func apply(_ scenario: ScenarioDraft) throws { try commit(scenario.applying(to: state)) }

  func setTimeZone(_ identifier: String) throws {
    guard TimeZone(identifier: identifier) != nil else {
      throw StoreError.validation("Invalid time zone.")
    }
    var updated = state
    updated.timeZoneID = identifier
    updated.revision += 1
    try commit(updated)
  }

  private func commit(_ updated: PlannerState) throws {
    let previous = record.payload
    record.payload = try JSONEncoder().encode(updated)
    do {
      try context.save()
      state = updated
    } catch {
      record.payload = previous
      throw error
    }
  }
}

enum StoreError: LocalizedError {
  case validation(String)
  var errorDescription: String? { if case .validation(let message) = self { message } else { nil } }
}

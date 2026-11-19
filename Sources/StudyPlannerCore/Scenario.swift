import Foundation

public struct ScenarioDraft: Sendable {
  public let baselineRevision: Int
  public let baseline: SchedulerReport
  public var input: PlannerInput
  public let context: PlanningContext
  public init(state: PlannerState, context: PlanningContext) {
    baselineRevision = state.revision
    input = state.input
    self.context = context
    baseline = Scheduler.generate(state.input, context: context)
  }
  public var proposed: SchedulerReport { Scheduler.generate(input, context: context) }
  public var changedSessions: Int {
    let old = Set(baseline.sessions.map { "\($0.id)-\($0.end.timeIntervalSince1970)" })
    let new = Set(proposed.sessions.map { "\($0.id)-\($0.end.timeIntervalSince1970)" })
    return old.symmetricDifference(new).count
  }
  public func applying(to state: PlannerState) throws -> PlannerState {
    guard state.revision == baselineRevision else { throw ScenarioError.baselineChanged }
    let report = proposed
    guard report.status != .invalidInput else { throw ScenarioError.invalidInput }
    var updated = state
    updated.input = input
    updated.revision += 1
    updated.approvedPlan = ApprovedPlan(input: input, report: report, revision: updated.revision)
    return updated
  }
}

public enum ScenarioError: LocalizedError {
  case baselineChanged, invalidInput
  public var errorDescription: String? {
    switch self {
    case .baselineChanged: "The baseline changed. Discard this draft and create a new scenario."
    case .invalidInput: "Fix the invalid scenario inputs before applying."
    }
  }
}

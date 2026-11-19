import Foundation

public enum Priority: Int, Codable, CaseIterable, Sendable {
  case low, medium, high
}

public struct Course: Identifiable, Codable, Equatable, Sendable {
  public var id = UUID()
  public var name: String
  public var color = "blue"
  public init(name: String) { self.name = name }
}

public struct AcademicTask: Identifiable, Codable, Equatable, Sendable {
  public var id = UUID()
  public var courseID: UUID
  public var title: String
  public var deadline: Date
  public var estimatedMinutes: Int
  public var remainingMinutes: Int
  public var priority: Priority
  public var isComplete: Bool { remainingMinutes == 0 }
  public init(
    courseID: UUID, title: String, deadline: Date, minutes: Int, priority: Priority = .medium
  ) {
    self.courseID = courseID
    self.title = title
    self.deadline = deadline
    estimatedMinutes = minutes
    remainingMinutes = minutes
    self.priority = priority
  }
}

/// Weekdays use Foundation's convention: Sunday = 1. Windows cannot cross midnight.
public struct WeeklyWindow: Identifiable, Codable, Equatable, Sendable {
  public var id = UUID()
  public var weekday: Int
  public var startMinute: Int
  public var endMinute: Int
  public init(weekday: Int, startMinute: Int, endMinute: Int) {
    self.weekday = weekday
    self.startMinute = startMinute
    self.endMinute = endMinute
  }
}

public struct FixedCommitment: Identifiable, Codable, Equatable, Sendable {
  public var id = UUID()
  public var title: String
  public var start: Date
  public var end: Date
  public var repeatsWeekly: Bool
  public init(title: String, start: Date, end: Date, repeatsWeekly: Bool = false) {
    self.title = title
    self.start = start
    self.end = end
    self.repeatsWeekly = repeatsWeekly
  }
}

public struct PlannerInput: Codable, Equatable, Sendable {
  public var courses: [Course] = []
  public var tasks: [AcademicTask] = []
  public var availability: [WeeklyWindow] = []
  public var commitments: [FixedCommitment] = []
  public init() {}
}

public struct PlanningContext: Codable, Equatable, Sendable {
  public var start: Date
  public var timeZoneID: String
  public var maximumSessionMinutes = 60
  public var minimumSessionMinutes = 30
  public init(start: Date, timeZoneID: String) {
    self.start = start
    self.timeZoneID = timeZoneID
  }
}

public struct StudySession: Identifiable, Codable, Equatable, Sendable {
  public var id: String { "\(taskID.uuidString)-\(start.timeIntervalSince1970)" }
  public var taskID: UUID
  public var start: Date
  public var end: Date
  public var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

public enum Feasibility: String, Codable, Sendable {
  case fullyScheduled = "Fully Scheduled"
  case overCapacity = "Over Capacity"
  case needsAdjustment = "Needs Adjustment"
  case invalidInput = "Invalid Input"
}

public struct SchedulerReport: Codable, Equatable, Sendable {
  public var context: PlanningContext
  public var horizonEnd: Date
  public var status: Feasibility
  public var sessions: [StudySession] = []
  public var availableMinutes = 0
  public var requiredMinutes = 0
  public var scheduledMinutes: Int { sessions.reduce(0) { $0 + $1.minutes } }
  public var unscheduledMinutes: Int { requiredMinutes - scheduledMinutes }
  public var fullyScheduledTasks = 0
  public var atRiskTasks = 0
  public var outsideHorizonTasks = 0
  public var explanations: [String] = []
}

public struct ApprovedPlan: Codable, Equatable, Sendable {
  public var input: PlannerInput
  public var report: SchedulerReport
  public var revision: Int

  public init(input: PlannerInput, report: SchedulerReport, revision: Int) {
    self.input = input
    self.report = report
    self.revision = revision
  }

  public func isStale(input: PlannerInput, timeZoneID: String) -> Bool {
    self.input != input || report.context.timeZoneID != timeZoneID
  }
}

public struct PlannerState: Codable, Equatable, Sendable {
  public var input = PlannerInput()
  public var timeZoneID = TimeZone.current.identifier
  public var revision = 0
  public var approvedPlan: ApprovedPlan?
  public init() {}
}

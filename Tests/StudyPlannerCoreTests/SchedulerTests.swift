import Foundation
import XCTest

@testable import StudyPlannerCore

final class SchedulerTests: XCTestCase {
  // Fixed instant; no dependency on Date.now.
  let start = Date(timeIntervalSince1970: 1_799_712_000)
  var context: PlanningContext { PlanningContext(start: start, timeZoneID: "UTC") }

  func fixture(minutes: Int = 120, capacity: Int = 120) -> PlannerInput {
    var input = PlannerInput()
    let course = Course(name: "Algorithms")
    input.courses = [course]
    input.tasks = [
      AcademicTask(
        courseID: course.id, title: "Assignment", deadline: start.addingTimeInterval(86400),
        minutes: minutes)
    ]
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let minute =
      calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
    input.availability = [
      WeeklyWindow(
        weekday: calendar.component(.weekday, from: start), startMinute: minute,
        endMinute: minute + capacity)
    ]
    return input
  }

  func testNormalAndDeterministic() {
    let input = fixture()
    let report = Scheduler.generate(input, context: context)
    XCTAssertEqual(report.status, .fullyScheduled)
    XCTAssertEqual(report.scheduledMinutes, 120)
    XCTAssertEqual(report.sessions.count, 2)
    XCTAssertEqual(report, Scheduler.generate(input, context: context))
  }

  func testCommitmentAndCapacityProof() {
    var input = fixture()
    input.commitments = [
      FixedCommitment(title: "Lecture", start: start, end: start.addingTimeInterval(3600))
    ]
    let report = Scheduler.generate(input, context: context)
    XCTAssertEqual(report.status, .overCapacity)
    XCTAssertEqual(report.unscheduledMinutes, 60)
    XCTAssertTrue(report.sessions.allSatisfy { $0.start >= start.addingTimeInterval(3600) })
  }

  func testShortWorkIsAdjustmentNotProofOfOverload() {
    let report = Scheduler.generate(fixture(minutes: 20), context: context)
    XCTAssertEqual(report.status, .needsAdjustment)
    XCTAssertEqual(report.unscheduledMinutes, 20)
  }

  func testOverdueOutsideHorizonAndInvalidInput() {
    var input = fixture()
    input.tasks[0].deadline = start.addingTimeInterval(-60)
    XCTAssertEqual(Scheduler.generate(input, context: context).sessions.count, 0)
    input.tasks[0].deadline = start.addingTimeInterval(15 * 86400)
    let outside = Scheduler.generate(input, context: context)
    XCTAssertEqual(outside.outsideHorizonTasks, 1)
    XCTAssertEqual(outside.requiredMinutes, 0)
    input.tasks[0].remainingMinutes = -1
    XCTAssertEqual(Scheduler.generate(input, context: context).status, .invalidInput)
  }

  func testScenarioIsolationApplyAndStaleness() throws {
    var state = PlannerState()
    state.input = fixture(minutes: 180)
    var draft = ScenarioDraft(state: state, context: context)
    draft.input.tasks[0].remainingMinutes = 120
    XCTAssertEqual(state.input.tasks[0].remainingMinutes, 180)
    XCTAssertEqual(draft.baseline.unscheduledMinutes, 60)
    XCTAssertEqual(draft.proposed.unscheduledMinutes, 0)
    let applied = try draft.applying(to: state)
    XCTAssertEqual(applied.input.tasks[0].remainingMinutes, 120)
    XCTAssertNotNil(applied.approvedPlan)
    state.revision += 1
    XCTAssertThrowsError(try draft.applying(to: state))
    XCTAssertTrue(applied.approvedPlan!.isStale(input: state.input, timeZoneID: "UTC"))
  }

  func testNoAvailabilityAndMergedWindows() {
    var input = fixture()
    input.availability.append(input.availability[0])
    XCTAssertEqual(Scheduler.generate(input, context: context).scheduledMinutes, 120)
    input.availability = []
    let report = Scheduler.generate(input, context: context)
    XCTAssertEqual(report.status, .overCapacity)
    XCTAssertEqual(report.availableMinutes, 0)
    XCTAssertTrue(report.sessions.isEmpty)
  }

  func testSnapshotRoundTrip() throws {
    var state = PlannerState()
    state.input = fixture()
    let report = Scheduler.generate(state.input, context: context)
    state.approvedPlan = ApprovedPlan(input: state.input, report: report, revision: 0)
    XCTAssertEqual(
      state, try JSONDecoder().decode(PlannerState.self, from: JSONEncoder().encode(state)))
  }

  func testGeneratedScheduleInvariants() {
    for amount in stride(from: 30, through: 600, by: 15) {
      var input = fixture(minutes: amount, capacity: 240)
      var second = input.tasks[0]
      second.id = UUID()
      second.priority = .high
      input.tasks.append(second)
      let report = Scheduler.generate(input, context: context)
      for (index, session) in report.sessions.enumerated() {
        XCTAssertGreaterThanOrEqual(session.start, start)
        XCTAssertLessThanOrEqual(session.end, input.tasks[0].deadline)
        XCTAssertTrue((30...60).contains(session.minutes))
        if index > 0 { XCTAssertGreaterThanOrEqual(session.start, report.sessions[index - 1].end) }
      }
      XCTAssertEqual(report.scheduledMinutes + report.unscheduledMinutes, report.requiredMinutes)
      for task in input.tasks {
        XCTAssertLessThanOrEqual(
          report.sessions.filter { $0.taskID == task.id }.reduce(0) { $0 + $1.minutes },
          task.remainingMinutes)
      }
    }
  }

  func testWeeklyCommitmentAndDeadlineTie() {
    var input = fixture(minutes: 60)
    var second = input.tasks[0]
    second.id = UUID()
    second.priority = .high
    input.tasks.append(second)
    input.commitments = [
      FixedCommitment(
        title: "Weekly class", start: start, end: start.addingTimeInterval(3600),
        repeatsWeekly: true)
    ]
    let report = Scheduler.generate(input, context: context)
    XCTAssertEqual(report.sessions.first?.taskID, second.id)
    XCTAssertEqual(report.scheduledMinutes, 60)
  }

  func testDSTAndHorizonUseCalendarDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
    let context = PlanningContext(start: start, timeZoneID: "America/New_York")
    let course = Course(name: "Math")
    var input = PlannerInput()
    input.courses = [course]
    input.tasks = [
      AcademicTask(
        courseID: course.id, title: "DST", deadline: start.addingTimeInterval(86400), minutes: 60)
    ]
    input.availability = [WeeklyWindow(weekday: 1, startMinute: 60, endMinute: 240)]
    let report = Scheduler.generate(input, context: context)
    XCTAssertEqual(report.scheduledMinutes, 60)
    XCTAssertEqual(report.horizonEnd, calendar.date(byAdding: .day, value: 14, to: start))
    // 2 real hours on DST day, 3 the following Sunday.
    XCTAssertEqual(report.availableMinutes, 300)
  }

  func testDeadlineBoundaryAndSessionRemainders() {
    for minutes in [31, 59, 61, 80, 119, 121] {
      var input = fixture(minutes: minutes, capacity: 240)
      input.tasks[0].deadline = start.addingTimeInterval(Double(minutes * 60))
      let report = Scheduler.generate(input, context: context)
      XCTAssertEqual(report.scheduledMinutes, minutes)
      XCTAssertTrue(report.sessions.allSatisfy { $0.end <= input.tasks[0].deadline })
    }
  }
}

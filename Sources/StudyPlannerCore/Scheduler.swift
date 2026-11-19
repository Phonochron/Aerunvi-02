import Foundation

public enum Scheduler {
  private struct Slot {
    var start: Date
    var end: Date
    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
  }

  public static func generate(_ input: PlannerInput, context: PlanningContext) -> SchedulerReport {
    var calendar = Calendar(identifier: .gregorian)
    guard let zone = TimeZone(identifier: context.timeZoneID) else {
      return invalid(context, "Choose a valid time zone.")
    }
    calendar.timeZone = zone
    guard context.start.timeIntervalSince1970.isFinite,
      let end = calendar.date(byAdding: .day, value: 14, to: context.start)
    else {
      return invalid(context, "Invalid planning start.")
    }
    var result = SchedulerReport(context: context, horizonEnd: end, status: .fullyScheduled)
    let timestamp = ISO8601DateFormatter()
    timestamp.timeZone = zone
    let errors = validate(input, context: context)
    guard errors.isEmpty else {
      result.status = .invalidInput
      result.explanations = errors
      return result
    }
    let lower = Date(timeIntervalSince1970: ceil(context.start.timeIntervalSince1970 / 60) * 60)
    var windows: [Slot] = []
    var blocks = input.commitments.filter { !$0.repeatsWeekly }.map {
      Slot(start: $0.start, end: $0.end)
    }
    var day = calendar.startOfDay(for: context.start)
    while day < end {
      let weekday = calendar.component(.weekday, from: day)
      for window in input.availability where window.weekday == weekday {
        windows.append(
          Slot(
            start: max(lower, clock(window.startMinute, on: day, calendar: calendar)),
            end: min(end, clock(window.endMinute, on: day, calendar: calendar))))
      }
      for commitment in input.commitments where commitment.repeatsWeekly {
        guard weekday == calendar.component(.weekday, from: commitment.start) else { continue }
        let startMinute =
          calendar.component(.hour, from: commitment.start) * 60
          + calendar.component(.minute, from: commitment.start)
        let endMinute =
          calendar.component(.hour, from: commitment.end) * 60
          + calendar.component(.minute, from: commitment.end)
        let start = clock(startMinute, on: day, calendar: calendar)
        if day >= calendar.startOfDay(for: commitment.start) {
          blocks.append(Slot(start: start, end: clock(endMinute, on: day, calendar: calendar)))
        }
      }
      day = calendar.date(byAdding: .day, value: 1, to: day)!
    }
    var free = merge(windows.filter { $0.end > $0.start })
    for block in merge(blocks) {
      free = free.flatMap { slot -> [Slot] in
        guard block.start < slot.end && block.end > slot.start else { return [slot] }
        return [
          Slot(start: slot.start, end: min(slot.end, block.start)),
          Slot(start: max(slot.start, block.end), end: slot.end),
        ].filter { $0.minutes > 0 }
      }
    }
    let capacity = free
    result.availableMinutes = capacity.reduce(0) { $0 + $1.minutes }
    let pending = input.tasks.filter { !$0.isComplete }
    result.outsideHorizonTasks = pending.filter { $0.deadline > end }.count
    let tasks = pending.filter { $0.deadline <= end }.sorted {
      if $0.deadline != $1.deadline { return $0.deadline < $1.deadline }
      if $0.priority != $1.priority { return $0.priority.rawValue > $1.priority.rawValue }
      return $0.id.uuidString < $1.id.uuidString
    }
    result.requiredMinutes = tasks.reduce(0) { $0 + $1.remainingMinutes }
    var cumulative = 0
    var provenOverload = false
    for task in tasks {
      cumulative += task.remainingMinutes
      let minutesBeforeDeadline = capacity.reduce(0) {
        $0 + max(0, Int(min($1.end, task.deadline).timeIntervalSince($1.start) / 60))
      }
      if cumulative > minutesBeforeDeadline {
        provenOverload = true
        result.explanations.append(
          "By \(timestamp.string(from: task.deadline)), required work exceeds available capacity by at least \(cumulative - minutesBeforeDeadline) minutes."
        )
      }
      var remaining = task.remainingMinutes
      for index in free.indices {
        while remaining >= context.minimumSessionMinutes {
          let available = max(
            0, Int(min(free[index].end, task.deadline).timeIntervalSince(free[index].start) / 60))
          var length = min(remaining, min(available, context.maximumSessionMinutes))
          // Keep the final remainder valid when a different split fits this slot.
          let tail = remaining - length
          if tail > 0 && tail < context.minimumSessionMinutes
            && remaining >= 2 * context.minimumSessionMinutes
          {
            length = min(length, remaining - context.minimumSessionMinutes)
          }
          guard length >= context.minimumSessionMinutes else { break }
          let finish = free[index].start.addingTimeInterval(Double(length * 60))
          result.sessions.append(
            StudySession(taskID: task.id, start: free[index].start, end: finish))
          free[index].start = finish
          remaining -= length
        }
      }
      if remaining == 0 {
        result.fullyScheduledTasks += 1
      } else {
        result.atRiskTasks += 1
        let reason =
          task.deadline <= context.start
          ? "Deadline has passed." : "No placement found under the session and availability rules."
        result.explanations.append("\(task.title): \(remaining) minutes unscheduled. \(reason)")
      }
    }
    result.sessions.sort { $0.start < $1.start }
    if result.unscheduledMinutes > 0 {
      result.status = provenOverload ? .overCapacity : .needsAdjustment
    }
    if result.outsideHorizonTasks > 0 {
      result.explanations.append(
        "\(result.outsideHorizonTasks) tasks are outside the 14-day planning horizon and excluded from workload metrics."
      )
    }
    return result
  }

  public static func validate(_ input: PlannerInput, context: PlanningContext) -> [String] {
    var errors: [String] = []
    if context.minimumSessionMinutes < 1
      || context.maximumSessionMinutes < context.minimumSessionMinutes
      || context.maximumSessionMinutes > 1440
    {
      errors.append("Session length must be between 1 and 1440 minutes, with minimum <= maximum.")
    }
    if input.tasks.count > 1000 { errors.append("Use at most 1000 tasks per plan.") }
    if Set(input.courses.map(\.id)).count != input.courses.count
      || Set(input.tasks.map(\.id)).count != input.tasks.count
    {
      errors.append("Course and task IDs must be unique.")
    }
    for course in input.courses
    where course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      errors.append("Course name cannot be empty.")
    }
    let courseIDs = Set(input.courses.map(\.id))
    for task in input.tasks {
      if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !courseIDs.contains(task.courseID) || !(1...525600).contains(task.estimatedMinutes)
        || !(0...task.estimatedMinutes).contains(task.remainingMinutes)
        || !task.deadline.timeIntervalSince1970.isFinite
      {
        errors.append(
          "Invalid task: title, course, deadline or duration (remaining must be 0...estimate; estimate <= 525600)."
        )
      }
    }
    for window in input.availability
    where !(1...7).contains(window.weekday) || window.startMinute < 0 || window.endMinute > 1440
      || window.startMinute >= window.endMinute
    {
      errors.append("Study windows must have a weekday and increasing times within one day.")
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: context.timeZoneID) ?? .gmt
    for block in input.commitments {
      if block.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !block.start.timeIntervalSince1970.isFinite || !block.end.timeIntervalSince1970.isFinite
        || block.start >= block.end
        || (block.repeatsWeekly && !calendar.isDate(block.start, inSameDayAs: block.end))
      {
        errors.append(
          "Commitments need a title and increasing dates. Split recurring overnight commitments at midnight."
        )
      }
    }
    return errors
  }

  private static func invalid(_ context: PlanningContext, _ reason: String) -> SchedulerReport {
    var report = SchedulerReport(context: context, horizonEnd: context.start, status: .invalidInput)
    report.explanations = [reason]
    return report
  }

  private static func clock(_ minute: Int, on day: Date, calendar: Calendar) -> Date {
    if minute == 1440 { return calendar.date(byAdding: .day, value: 1, to: day)! }
    // Foundation resolves missing spring-forward clock times to the next valid time.
    return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)!
  }

  private static func merge(_ slots: [Slot]) -> [Slot] {
    var merged: [Slot] = []
    for slot in slots.sorted(by: { $0.start < $1.start }) {
      if let last = merged.last, slot.start <= last.end {
        merged[merged.count - 1].end = max(last.end, slot.end)
      } else {
        merged.append(slot)
      }
    }
    return merged
  }
}

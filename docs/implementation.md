# Implementation and maintenance contract

## Ownership

`Models.swift` contains Codable value types. `Scheduler.swift` owns validation, availability expansion, blocked-time subtraction, deadline capacity checks and placement. `Scenario.swift` owns baseline isolation and revision-checked Apply. `PlannerStore.swift` loads/saves the whole state and exposes user actions; views keep transient form/preview state locally. Change these boundaries only when a concrete feature requires it.

Keep scheduling logic out of SwiftUI and SwiftData. Pass an explicit start instant and time-zone identifier; never read the clock inside the scheduler. Add a focused regression test for every scheduling bug. Avoid extracting a class or protocol for each small operation.

## Scheduling rules

- Gregorian calendar with the selected IANA time zone; horizon ends 14 calendar days after the start, not a fixed 336 hours across DST.
- Foundation resolves nonexistent spring-forward times forward and selects its default occurrence for repeated fall-back times. Sessions use real elapsed minutes. DST is covered by a core test.
- Availability repeats weekly, uses Sunday=1 through Saturday=7 and local minutes 0...1440. Each window stays within one day. Overlapping/touching availability is unioned before counting capacity.
- One-off commitments accept absolute date ranges. Weekly commitments stay within a local day and repeat from the initial date forward. Split recurring overnight commitments into separate entries.
- Intervals are `[start, end)`. Availability is clipped to planning start and horizon; blocked intervals are removed. Work is never placed after its deadline.
- Tasks use earliest deadline, then higher priority, then lexical UUID order. Completed tasks are excluded. Overdue remaining work is unscheduled and explained. Tasks due after the horizon are counted separately and excluded from workload metrics.
- Sessions have minimum 30 and maximum 60 real minutes. Rebalance the penultimate chunk where possible so the last chunk is valid. Do not exceed the maximum to absorb a short tail. Work that cannot meet the minimum remains unscheduled.
- A capacity proof compares cumulative remaining work due by each deadline with unioned free capacity before that deadline. This is a necessary bound, not an optimality claim. Otherwise incomplete placement is `Needs Adjustment`.
- Validate titles, course references, durations, duplicate course/task IDs, session settings and windows before scheduling. The current input limit is 1000 tasks; estimate is at most 525600 minutes per task. The proposed performance target concerns 100 tasks and remains unmeasured on iOS.

## User-controlled state

Generate creates a preview. Approve persists the preview only if input revision still matches. Updating input retains the approved plan and marks it stale. Planner also flags plans created before the current day. It never silently regenerates the approved schedule.

A scenario contains copied input, baseline revision and a fixed planning context. Baseline and proposed metrics use that same context. The baseline comparison is freshly evaluated from current input, rather than comparing against an older plan generated at a different time. Session changes count removed plus added `(task, start, end)` entries; a moved session counts as one removal and one addition.

Draft edits and Discard never write to SwiftData. Apply rejects an outdated baseline or invalid input, then saves input, approved plan and incremented revision as one snapshot. A failed save restores the prior in-memory payload. Storage/decode errors are displayed; saved data is never automatically reset. Schema version 1 is explicit; introduce migration before changing persisted fields incompatibly.

## Verification

| Check | Status |
|---|---|
| Swift core compilation and 11 XCTest cases | PASS on Windows / Swift 6.4.2 |
| Normal schedule, no overlap, blocked time, capacity proof | PASS |
| EDF/priority behavior, boundaries, short tails, no time, outside horizon, overdue | PASS |
| Determinism, DST, scenario isolation/revision guard, Codable round trip | PASS |
| Xcode build, signing, iPhone Simulator | NOT RUN: macOS unavailable |
| Two SwiftData persistence/Apply integration tests | AUTHORED, NOT RUN |
| Accessibility, Dynamic Type and UI flows | Source uses native controls; manual checks NOT RUN |
| 100-task generation <=2 seconds on reference iOS device | NOT MEASURED |
| Three student usability sessions | NOT RUN |

Core tests check multiple generated workloads; this is deterministic invariant testing, not an exhaustive proof. JSON round-trip tests do not establish SwiftData disk durability.

## First Mac verification

1. Build and run on iPhone Simulator. Resolve platform/compiler issues before extending features.
2. Run the app test scheme and `swift test`; verify save, terminate and reopen the app manually.
3. Exercise normal planning, a blocked hour, overload, add capacity in What-if, Discard, Apply and progress/stale-plan flows.
4. Verify accessibility labels, large text, scrolling and time-zone changes. Record simulator/device, OS and Xcode versions.
5. Measure a 100-task plan in a release build. Add a benchmark result only after measurement.

The supplied product definition is a proposed baseline. Competitor comparisons, effort estimates and market differentiation were not researched or validated during implementation. Check the university rubric before adding backend functionality; the current MVP is intentionally local-only.

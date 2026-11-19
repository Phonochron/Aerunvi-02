# Adaptive Study Planner

An offline iPhone planner that compares academic workload with available study time. Swift 6, SwiftUI, SwiftData; iOS 17 minimum. No third-party runtime dependencies.

**Status:** MVP source implemented. The pure Swift core passes Windows tests. The Xcode project, iOS UI, SwiftData disk persistence and Simulator flows are **NOT VERIFIED** until run on a Mac. This is not a completed or submission-ready iOS app yet.

## Run on macOS

1. Open `AdaptiveStudyPlanner.xcodeproj` in Xcode 16 or newer with an installed iOS Simulator runtime.
2. Select the `AdaptiveStudyPlanner` scheme and an available iPhone Simulator, then Run. Set your development team and a unique bundle identifier if using a physical device.
3. Choose **Manage tasks and availability**. Add a course, a task and study windows before its deadline; Save.
4. Generate a 14-day preview, inspect its explanation and Approve it.
5. In What-if, create a scenario, edit its inputs and compare results. Apply saves both input and schedule; Discard leaves saved data untouched.
6. Use Product → Test to run the two SwiftData integration tests. Run `swift test` at the repository root for core tests. Record Xcode/iOS versions and results before calling the MVP verified.

## Test the core on Windows

Run PowerShell from this folder:

```powershell
$env:CLANG_MODULE_CACHE_PATH = Join-Path $env:TEMP 'StudyPlanner-ModuleCache'
swift test --build-system native -j 2 -Xswiftc -module-cache-path -Xswiftc $env:CLANG_MODULE_CACHE_PATH
```

The installed Swift 6.4.2 default `swiftbuild` backend stalled in earlier environment checks; the native backend completes these tests. It is deprecated, so this is a local toolchain workaround. Prefer normal `swift test` where the default backend works. A Windows SDK `wchar_t` module warning was observed on the first build; tests still completed successfully.

## Structure

```text
Sources/StudyPlannerCore/   Value models, deterministic scheduler, scenario transactions
Tests/StudyPlannerCoreTests/ Scheduling and state-isolation tests
App/                        SwiftUI screens and one observable persistence store
AppTests/                   SwiftData integration tests (Mac only)
AdaptiveStudyPlanner.xcodeproj/ iOS app, test target and shared scheme
docs/implementation.md      Rules, design choices and verification checklist
```

The UI knows about the core; the core imports only Foundation. `PlannerStore` owns saved state and is the only SwiftData boundary. Input forms edit local copies. There are no repository protocols, service containers or feature packages to maintain before they are needed.

## Current limits

- This deterministic heuristic is not a global optimizer. `Over Capacity` requires a deadline-prefix capacity proof; unsuccessful placements without such proof are `Needs Adjustment`.
- Sessions are 30–60 minutes. A final chunk is rebalanced when possible; work below 30 minutes stays unscheduled. Split overnight recurring windows at midnight.
- The horizon is 14 local calendar days from an explicit planning instant. Later deadlines are excluded and counted separately. Weekly commitments repeat from their initial local date forward.
- The three tabs combine workload entry, planner, what-if and settings; a separate dashboard adds no MVP behavior.
- SwiftData stores one versioned snapshot. For this bounded MVP that makes Apply atomic and avoids two competing model graphs. Large histories or independent queries would justify normalized persistence models and a migration.
- App icons, visual polish, UI automation, the device performance target and usability sessions are pending. No backend, accounts, calendar sync or AI features are included.

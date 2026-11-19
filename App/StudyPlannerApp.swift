import SwiftData
import SwiftUI

@main
struct StudyPlannerApp: App {
  @State private var store: PlannerStore?
  @State private var startupError: String?

  var body: some Scene {
    WindowGroup {
      Group {
        if let store {
          PlannerView(store: store)
        } else if let startupError {
          ContentUnavailableView(
            "Unable to open saved planner", systemImage: "externaldrive.badge.exclamationmark",
            description: Text(startupError + " Your saved data has not been reset."))
        } else {
          ProgressView("Opening planner…")
        }
      }
      .task {
        guard store == nil && startupError == nil else { return }
        do {
          let configuration = ModelConfiguration(cloudKitDatabase: .none)
          let container = try ModelContainer(for: StoredPlanner.self, configurations: configuration)
          store = try PlannerStore(container: container)
        } catch { startupError = error.localizedDescription }
      }
    }
  }
}

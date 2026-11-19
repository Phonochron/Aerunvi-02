import Foundation
import StudyPlannerCore
import SwiftData
import XCTest

@testable import AdaptiveStudyPlanner

@MainActor
final class PersistenceTests: XCTestCase {
  func testDiskReloadAndDiscardDoNotLoseData() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("planner.store")
    let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
    let container = try ModelContainer(for: StoredPlanner.self, configurations: configuration)
    let store = try PlannerStore(container: container)
    var input = PlannerInput()
    input.courses = [Course(name: "Algorithms")]
    try store.save(input: input)
    var draft = ScenarioDraft(state: store.state, context: store.planningContext())
    draft.input.courses[0].name = "Discarded edit"
    // No apply call: draft edits must never reach persistence.
    let reopenedContainer = try ModelContainer(
      for: StoredPlanner.self, configurations: configuration)
    let reopened = try PlannerStore(container: reopenedContainer)
    XCTAssertEqual(reopened.state.input, input)
    XCTAssertEqual(reopened.state.input.courses[0].name, "Algorithms")
  }

  func testApplyPersistsInputAndScheduleTogether() throws {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: StoredPlanner.self, configurations: configuration)
    let store = try PlannerStore(container: container)
    var draft = ScenarioDraft(state: store.state, context: store.planningContext())
    draft.input.courses = [Course(name: "Applied course")]
    try store.apply(draft)
    let reloaded = try PlannerStore(container: container)
    XCTAssertEqual(reloaded.state.input, draft.input)
    XCTAssertEqual(reloaded.state.approvedPlan?.input, draft.input)
    XCTAssertEqual(reloaded.state.revision, 1)
  }
}

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "StudyPlannerCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "StudyPlannerCore", targets: ["StudyPlannerCore"])],
  targets: [
    .target(name: "StudyPlannerCore"),
    .testTarget(name: "StudyPlannerCoreTests", dependencies: ["StudyPlannerCore"]),
  ]
)

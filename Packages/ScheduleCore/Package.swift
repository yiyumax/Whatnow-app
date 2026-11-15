// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScheduleCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "ScheduleCore", targets: ["ScheduleCore"])
    ],
    targets: [
        .target(name: "ScheduleCore"),
        .testTarget(name: "ScheduleCoreTests", dependencies: ["ScheduleCore"])
    ]
)

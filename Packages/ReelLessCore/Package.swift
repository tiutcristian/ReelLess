// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReelLessCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "ReelLessCore", targets: ["ReelLessCore"])],
    targets: [
        .target(name: "ReelLessCore", resources: [.copy("Resources/rule-pack.default.json")]),
        .testTarget(name: "ReelLessCoreTests", dependencies: ["ReelLessCore"]),
    ]
)

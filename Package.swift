// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VerseDock",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "VerseCore", targets: ["VerseCore"])],
    targets: [
        .target(name: "VerseCore"),
        .testTarget(name: "VerseCoreTests", dependencies: ["VerseCore"])
    ]
)

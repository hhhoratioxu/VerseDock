// swift-tools-version: 5.9
import PackageDescription
import Foundation

let manifestURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Config/SwiftSources.json")
struct BuildSources: Decodable { let core: [String]; let tests: [String] }
let sourceGroups = try JSONDecoder().decode(BuildSources.self, from: Data(contentsOf: manifestURL))

let package = Package(
    name: "VerseDock",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "VerseCore", targets: ["VerseCore"])],
    targets: [
        .target(name: "VerseCore", sources: sourceGroups.core.map { URL(fileURLWithPath: $0).lastPathComponent }),
        .testTarget(name: "VerseCoreTests", dependencies: ["VerseCore"],
                    sources: sourceGroups.tests.map { URL(fileURLWithPath: $0).lastPathComponent })
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkItDownSwift",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MarkItDownSwift",
            path: "Sources/MarkItDownSwift",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MarkItDownSwiftTests",
            dependencies: ["MarkItDownSwift"],
            path: "Tests/MarkItDownSwiftTests"
        ),
    ]
)

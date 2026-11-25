// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MessageBoard", platforms: [.macOS(.v14)], targets: [
    .executableTarget(name: "MessageBoard", path: "Sources")
])

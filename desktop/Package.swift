// swift-tools-version: 5.8
import PackageDescription
let package = Package(
    name: "ClaurstDesktop",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ClaurstDesktop", targets: ["AssistantApp"])],
    targets: [
        .target(name: "DesktopCore"),
        .executableTarget(name: "AssistantApp", dependencies: ["DesktopCore"]),
        .executableTarget(name: "DesktopIntegrationTests", dependencies: ["DesktopCore"], path: "Tests/DesktopCoreTests", exclude: ["LiveModelChecks.swift"])
    ]
)

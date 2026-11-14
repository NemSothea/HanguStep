// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HanguStepKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "Assistant", targets: ["Assistant"]),
    ],
    targets: [
        // Pure business rules. No UI, no persistence framework.
        .target(name: "Domain"),
        // Repository implementations. Depends on Domain only.
        .target(
            name: "Persistence",
            dependencies: ["Domain"],
            resources: [.process("Resources/HanguStep.xcdatamodeld"), .copy("Resources/Content")]
        ),
        // Tokens and reusable SwiftUI components. No domain knowledge.
        .target(name: "DesignSystem", resources: [.process("Resources")]),
        // Screens and view models. Talks to Domain through use cases.
        .target(name: "Features", dependencies: ["Domain", "DesignSystem"]),
        // Network-backed assistant providers (Phase 8). Depends on Domain only; the app
        // composes it, Features never imports it.
        .target(name: "Assistant", dependencies: ["Domain"]),
        // Content authoring tool: validates the bundled JSON and generates meaning questions.
        .executableTarget(name: "content-lint", dependencies: ["Domain", "Persistence"], path: "Sources/ContentLint"),

        .testTarget(name: "DomainTests", dependencies: ["Domain", "Persistence"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"], resources: [.copy("Fixtures")]),
        .testTarget(name: "AssistantTests", dependencies: ["Assistant", "Persistence"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "FeaturesTests", dependencies: ["Features", "Persistence"]),
    ],
    swiftLanguageModes: [.v6]
)

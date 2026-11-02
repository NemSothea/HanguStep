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
    ],
    targets: [
        // Pure business rules. No UI, no persistence framework.
        .target(name: "Domain"),
        // Repository implementations. Depends on Domain only.
        .target(name: "Persistence", dependencies: ["Domain"], resources: [.process("Resources")]),
        // Tokens and reusable SwiftUI components. No domain knowledge.
        .target(name: "DesignSystem", resources: [.process("Resources")]),
        // Screens and view models. Talks to Domain through use cases.
        .target(name: "Features", dependencies: ["Domain", "DesignSystem"]),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"], resources: [.copy("Fixtures")]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "FeaturesTests", dependencies: ["Features"]),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TinyBridgeUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TinyBridgeUI", targets: ["TinyBridgeUI"]),
        .library(name: "TinyBridgeClient", targets: ["TinyBridgeClient"]),
        .library(name: "VMConfiguration", targets: ["VMConfiguration"]),
        .library(name: "VMObservability", targets: ["VMObservability"]),
    ],
    targets: [
        // Typed client boundary for the TinyBridge control plane (JSON-RPC over
        // a Unix-domain socket). Depends on nothing else so it stays testable
        // in isolation, with no running VM required.
        .target(
            name: "TinyBridgeClient",
            path: "Sources/TinyBridgeClient"
        ),
        // VM configuration models + validation. Pure value logic, no I/O.
        .target(
            name: "VMConfiguration",
            path: "Sources/VMConfiguration"
        ),
        // Metrics history, normalization, and diagnostic redaction. Pure logic.
        .target(
            name: "VMObservability",
            path: "Sources/VMObservability"
        ),
        // The native SwiftUI application.
        .executableTarget(
            name: "TinyBridgeUI",
            dependencies: ["TinyBridgeClient", "VMConfiguration", "VMObservability"],
            path: "Sources/TinyBridgeUI"
        ),

        .testTarget(
            name: "TinyBridgeClientTests",
            dependencies: ["TinyBridgeClient"],
            path: "Tests/TinyBridgeClientTests"
        ),
        .testTarget(
            name: "VMConfigurationTests",
            dependencies: ["VMConfiguration"],
            path: "Tests/VMConfigurationTests"
        ),
        .testTarget(
            name: "VMObservabilityTests",
            dependencies: ["VMObservability"],
            path: "Tests/VMObservabilityTests"
        ),
    ]
)

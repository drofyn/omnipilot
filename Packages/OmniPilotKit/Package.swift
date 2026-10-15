// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OmniPilotKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "OmniPilotKit", targets: ["OmniPilotKit"])
    ],
    targets: [
        .target(
            name: "OmniPilotKit",
            path: "Sources/OmniPilotKit"
        ),
        .testTarget(
            name: "OmniPilotKitTests",
            dependencies: ["OmniPilotKit"],
            path: "Tests/OmniPilotKitTests"
        )
    ]
)

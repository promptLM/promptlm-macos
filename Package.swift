// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PromptLMMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PromptLMMac", targets: ["PromptLMMac"])
    ],
    targets: [
        .executableTarget(
            name: "PromptLMMac",
            path: "Sources/PromptLMMac"
        ),
        .testTarget(
            name: "PromptLMMacTests",
            dependencies: ["PromptLMMac"],
            path: "Tests/PromptLMMacTests"
        )
    ]
)

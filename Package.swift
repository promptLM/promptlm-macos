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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "PromptLMMac",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/PromptLMMac"
        ),
        .testTarget(
            name: "PromptLMMacTests",
            dependencies: ["PromptLMMac"],
            path: "Tests/PromptLMMacTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)

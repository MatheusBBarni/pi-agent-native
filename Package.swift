// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PiAgentNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PiAgentNativeCore", targets: ["PiAgentNativeCore"]),
        .executable(name: "PiAgentNative", targets: ["PiAgentNativeExecutable"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .target(
            name: "PiAgentNativeCore",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/PiAgentNative"
        ),
        .executableTarget(
            name: "PiAgentNativeExecutable",
            dependencies: ["PiAgentNativeCore"],
            path: "Sources/PiAgentNativeExecutable"
        )
    ]
)

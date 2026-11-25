// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "say-voice",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "SayVoiceCore", targets: ["SayVoiceCore"]),
        .executable(name: "say-voice", targets: ["SayVoiceCLI"]),
    ],
    targets: [
        .target(name: "SayVoiceCore"),
        .executableTarget(
            name: "SayVoiceCLI",
            dependencies: ["SayVoiceCore"]
        ),
        .testTarget(
            name: "SayVoiceCoreTests",
            dependencies: ["SayVoiceCore"]
        ),
    ]
)

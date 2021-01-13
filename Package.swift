// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "LaunchDarkly",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .watchOS(.v3),
        .tvOS(.v10)
    ],
    products: [
        .library(
            name: "LaunchDarkly",
            targets: ["LaunchDarkly"]),
    ],
    dependencies: [
        .package(name: "LDSwiftEventSource", url: "https://github.com/LaunchDarkly/swift-eventsource.git", .upToNextMinor(from: "1.2.0")),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", .upToNextMinor(from: "9.0.0")),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMinor(from: "3.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMinor(from: "9.0.0")),
    ],
    targets: [
        .target(
            name: "LaunchDarkly",
            dependencies: [
                .product(name: "LDSwiftEventSourceStatic", package: "LDSwiftEventSource")
            ],
            path: "LaunchDarkly/LaunchDarkly",
            exclude: ["Support"]),
        .testTarget(
            name: "LaunchDarklyTests",
            dependencies: [
                "LaunchDarkly",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble")],
            path: "LaunchDarkly",
            exclude: ["LaunchDarklyTests/Info.plist", "LaunchDarklyTests/.swiftlint.yml"],
            sources: ["GeneratedCode", "LaunchDarklyTests"]),
    ],
    swiftLanguageVersions: [.v5])

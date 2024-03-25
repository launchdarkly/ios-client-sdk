// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "LaunchDarkly",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
        .watchOS(.v4),
        .tvOS(.v11)
    ],
    products: [
        .library(
            name: "LaunchDarkly",
            targets: ["LaunchDarkly"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", exact: "9.1.0"),
        .package(url: "https://github.com/Quick/Quick.git", exact: "4.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", exact: "9.2.1"),
        .package(url: "https://github.com/LaunchDarkly/swift-eventsource.git", exact: "3.1.1")
    ],
    targets: [
        .target(
            name: "LaunchDarkly",
            dependencies: [
                .product(name: "LDSwiftEventSource", package: "swift-eventsource")
            ],
            path: "LaunchDarkly/LaunchDarkly",
            exclude: ["Support"]),
        .testTarget(
            name: "LaunchDarklyTests",
            dependencies: [
                "LaunchDarkly",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble")
            ],
            path: "LaunchDarkly",
            exclude: ["LaunchDarklyTests/Info.plist", "LaunchDarklyTests/.swiftlint.yml"],
            sources: ["GeneratedCode", "LaunchDarklyTests"]),
    ],
    swiftLanguageVersions: [.v5])

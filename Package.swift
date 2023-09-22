// swift-tools-version:5.2

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
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", .exact("9.1.0")),
        .package(url: "https://github.com/Quick/Quick.git", .exact("4.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .exact("9.2.1")),
        .package(name: "LDSwiftEventSource", url: "https://github.com/brianmichel/swift-eventsource.git", .branch("brian/add-windows-support")),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
    ],
    targets: [
        .target(
            name: "LaunchDarkly",
            dependencies: osSpecificLDDependencies(),
            path: "LaunchDarkly/LaunchDarkly",
            exclude: osSpecificExcludes()),
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

func osSpecificLDDependencies() -> [Target.Dependency] {
    #if os(Linux) || os(Windows)
    [
        .product(name: "LDSwiftEventSource", package: "LDSwiftEventSource"),
        .product(name: "Crypto", package: "swift-crypto"),
    ]
    #else
    [
        .product(name: "LDSwiftEventSource", package: "LDSwiftEventSource"),
    ]
    #endif
}

func osSpecificExcludes() -> [String] {
    #if os(Linux) || os(Windows)
    [
        "ObjectiveC",
        "Support",
    ]
    #else
    [
        "Support"
    ]
    #endif
}
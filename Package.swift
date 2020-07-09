// swift-tools-version:5.0

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
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "LaunchDarkly",
            targets: ["LaunchDarkly"]),
    ],
    dependencies: [
        // TODO change these to HTTPS once swift-eventsource is public.
        .package(url: "git@github.com:AliSoftware/OHHTTPStubs.git", from: "9.0.0"),
        .package(url: "git@github.com:Quick/Quick.git", from: "2.1.0"),
        .package(url: "git@github.com:Quick/Nimble.git", from: "8.0.2"),
        .package(url: "git@github.com:LaunchDarkly/swift-eventsource.git", from: "0.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "LaunchDarkly",
            dependencies: ["LDSwiftEventSource"],
            path: "LaunchDarkly/LaunchDarkly",
            exclude: ["Support"]),
        .testTarget(
            name: "LaunchDarklyTests",
            dependencies: ["LaunchDarkly", "OHHTTPStubsSwift", "Quick", "Nimble"],
            path: "LaunchDarkly",
            exclude: ["LaunchDarklyTests/Info.plist", "LaunchDarklyTests/.swiftlint.yml"],
            sources: ["GeneratedCode", "LaunchDarklyTests"])
    ],
    swiftLanguageVersions: [.v5])

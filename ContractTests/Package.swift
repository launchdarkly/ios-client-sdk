// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "ContractTests",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_15),
        .watchOS(.v4),
        .tvOS(.v11)
    ],
    products: [
        .executable(
            name: "ContractTests",
            targets: ["ContractTests"])
    ],
    dependencies: [
        Package.Dependency.package(name: "LaunchDarkly", path: ".."),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "ContractTests",
            dependencies: [
                .product(name: "LaunchDarkly", package: "LaunchDarkly"),
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Source"),
    ],
    swiftLanguageVersions: [.v5])

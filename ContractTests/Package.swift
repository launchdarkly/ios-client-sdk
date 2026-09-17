// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ContractTests",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS("9.0"),
        .tvOS(.v15)
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
            path: "Source")
    ],
    swiftLanguageVersions: [.v5])

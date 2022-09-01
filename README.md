LaunchDarkly SDK for iOS
========================

[![CircleCI](https://circleci.com/gh/launchdarkly/ios-client-sdk/tree/v6.svg?style=shield)](https://circleci.com/gh/launchdarkly/ios-client-sdk)
[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat)](https://swift.org/package-manager/)
[![CocoaPods compatible](https://img.shields.io/cocoapods/v/LaunchDarkly.svg)](https://cocoapods.org/pods/LaunchDarkly)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/LaunchDarkly.svg?style=flat)](https://docs.launchdarkly.com/sdk/client-side/ios)

LaunchDarkly overview
-------------------------
[LaunchDarkly](https://www.launchdarkly.com) is a feature management platform that serves over 100 billion feature flags daily to help teams build better software, faster. [Get started](https://docs.launchdarkly.com/home/getting-started) using LaunchDarkly today!

[![Twitter Follow](https://img.shields.io/twitter/follow/launchdarkly.svg?style=social&label=Follow&maxAge=2592000)](https://twitter.com/intent/follow?screen_name=launchdarkly)

Supported iOS and Xcode versions
-------------------------

This version of the LaunchDarkly SDK has been tested across iOS, macOS, watchOS, and tvOS devices.

The LaunchDarkly iOS SDK requires the following minimum build tool versions:

| Tool  | Version |
| ----- | ------- |
| Xcode | 11.4+   |
| Swift | 5.2+    |

And supports the following device platforms:

| Platform | Version |
| -------- | ------- |
| iOS      | 10.0    |
| watchOS  | 3.0     |
| tvOS     | 10.0    |
| macOS    | 10.12   |

Installation
-----------

LaunchDarkly supports multiple methods for installing the library in a project. Once installed, head over to the [SDK documentation](https://docs.launchdarkly.com/sdk/client-side/ios#getting-started) for complete instructions on getting started with using the SDK.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a dependency manager integrated into the `swift` compiler and Xcode.

To integrate LaunchDarkly into an Xcode project, go to the project editor, and select `Swift Packages`. From here hit the `+` button and follow the prompts using  `https://github.com/launchdarkly/ios-client-sdk.git` as the URL.

To include LaunchDarkly in a Swift package, simply add it to the dependencies section of your `Package.swift` file. And add the product "LaunchDarkly" as a dependency for your targets.

```swift
dependencies: [
    .package(url: "https://github.com/launchdarkly/ios-client-sdk.git", .upToNextMinor(from: "6.2.0"))
]
```

### CocoaPods

To use the [CocoaPods](https://cocoapods.org) dependency manager to integrate LaunchDarkly into your Xcode project, specify it in your `Podfile`:

```ruby
use_frameworks!
target 'YourTargetName' do
  pod 'LaunchDarkly', '~> 6.2'
end
```

### Carthage

To use the [Carthage](https://github.com/Carthage/Carthage) dependency manager to integrate LaunchDarkly into your Xcode project, specify it in your `Cartfile`:

To integrate LaunchDarkly into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "launchdarkly/ios-client-sdk" ~> 6.2
```

### Manual installation

If you prefer not to use the aforementioned dependency managers, it is possible to integrate the SDK manually.

1. On the root folder of the project retreive the SDK by either:
    * Adding the SDK as a git submodule with `git submodule add https://github.com/launchdarkly/ios-client-sdk.git`.
    * OR cloning the SDK with `git clone https://github.com/launchdarkly/ios-client-sdk.git`.
2. Open the new `ios-client-sdk` folder and drag `LaunchDarkly.xcodeproj` into the project navigator of your application's Xcode project. It should appear nested within your application's blue project icon.
3. Select your application project in the project navigator (blue icon) and select your application target under the "Targets" heading in the sidebar. If you have multiple targets, perform the following steps for each target.
4. Select the "General" tab, and if necessary expand the subsection "Frameworks, Libraries, and Embedded Content".
5. Click the "+" button in the expanded subsection. Under "LaunchDarkly" within the dialog you will see 4 frameworks, select `LaunchDarkly.framework` for iOS, or `LaunchDarkly_<platform>` for other platforms.

Learn more
-----------

Read our [documentation](https://docs.launchdarkly.com) for in-depth instructions on configuring and using LaunchDarkly. You can also head straight to the [complete reference guide for this SDK](https://docs.launchdarkly.com/sdk/client-side/ios).

Testing
-------

We run integration tests for all our SDKs using a centralized test harness. This approach gives us the ability to test for consistency across SDKs, as well as test networking behavior in a long-running application. These tests cover each method in the SDK, and verify that event sending, flag evaluation, stream reconnection, and other aspects of the SDK all behave correctly.

Contributing
------------

We encourage pull requests and other contributions from the community. Check out our [contributing guidelines](CONTRIBUTING.md) for instructions on how to contribute to this SDK.

About LaunchDarkly
-----------

* LaunchDarkly is a continuous delivery platform that provides feature flags as a service and allows developers to iterate quickly and safely. We allow you to easily flag your features and manage them from the LaunchDarkly dashboard.  With LaunchDarkly, you can:
    * Roll out a new feature to a subset of your users (like a group of users who opt-in to a beta tester group), gathering feedback and bug reports from real-world use cases.
    * Gradually roll out a feature to an increasing percentage of users, and track the effect that the feature has on key metrics (for instance, how likely is a user to complete a purchase if they have feature A versus feature B?).
    * Turn off a feature that you realize is causing performance problems in production, without needing to re-deploy, or even restart the application with a changed configuration file.
    * Grant access to certain features based on user attributes, like payment plan (eg: users on the ‘gold’ plan get access to more features than users in the ‘silver’ plan). Disable parts of your application to facilitate maintenance, without taking everything offline.
* LaunchDarkly provides feature flag SDKs for a wide variety of languages and technologies. Read [our documentation](https://docs.launchdarkly.com/sdk) for a complete list.
* Explore LaunchDarkly
    * [launchdarkly.com](https://www.launchdarkly.com/ "LaunchDarkly Main Website") for more information
    * [docs.launchdarkly.com](https://docs.launchdarkly.com/  "LaunchDarkly Documentation") for our documentation and SDK reference guides
    * [apidocs.launchdarkly.com](https://apidocs.launchdarkly.com/  "LaunchDarkly API Documentation") for our API documentation
    * [blog.launchdarkly.com](https://blog.launchdarkly.com/  "LaunchDarkly Blog Documentation") for the latest product updates

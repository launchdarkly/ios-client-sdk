LaunchDarkly SDK for iOS
========================

![CircleCI](https://circleci.com/gh/launchdarkly/ios-client/tree/master.svg?style=svg)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/LaunchDarkly.svg)](https://img.shields.io/cocoapods/v/LaunchDarkly.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/LaunchDarkly.svg?style=flat)](http://docs.launchdarkly.com/docs/ios-sdk-reference)

Installation
------------

LaunchDarkly supports multiple methods for installing the library in a project.

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C and Swift, which automates and simplifies the process of using 3rd-party libraries like LaunchDarkly in your projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

1. To integrate LaunchDarkly into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
use_frameworks!
target 'YourTargetName' do
  pod 'LaunchDarkly', '3.0.0-beta.3'
end
```

2. Then, run the following command from the project directory that contains the podfile:

```bash
$ pod install
```

3. Import the LaunchDarkly client into your project:

  Objective-C
```objective-c
@import LaunchDarkly;
```
  Swift
```swift
import LaunchDarkly
```

### Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

1. To integrate LaunchDarkly into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "launchdarkly/ios-client" "v3-beta"
```

2. Run `carthage update` to build the framework and drag the built `LaunchDarkly.framework` and `DarklyEventSource.framework` for your platform into your Xcode project. See `carthage help update` for details about building a particular configuration and platform.

NOTE: The iOS LaunchDarkly framework is `LaunchDarkly.framework`. Non-iOS frameworks include the platform name, e.g. `LaunchDarkly_watchOS`.

3. Once the frameworks have been installed into your project, on the project `General` tab, remove them from `Linked Frameworks and Libraries`, and add them to `Embedded Binaries`.

4. Import the LaunchDarkly client into your project. Be sure to add the platform for non-iOS frameworks.

Objective-C
```objective-c
@import LaunchDarkly;
```
or
```objective-c
@import LaunchDarkly_tvOS;
```
Swift
```swift
import LaunchDarkly
```
or
```swift
import LaunchDarkly_macOS
```

Quick setup
-----------

1. Add the SDK to your `Podfile`:

        pod 'LaunchDarkly', '3.0.0-beta.3'

2. Import the LaunchDarkly client into your project.

        @import LaunchDarkly;

    -- or --

        import LaunchDarkly

3. Instantiate a new LDClient with your mobile key and user:

        let config = LDConfig(mobileKey: my-mobile-key)

        let user = LDUser(key: "aa0ceb")

        LDClient.shared.start(config: config, user: user)

(Be sure to use a mobile key from your environments. Never embed a standard SDK key into a mobile application.)

### Installation without a package manager

1. On the root folder of the project, git clone the following two repositiories.
  - `git clone https://github.com/launchdarkly/ios-client`
  - `git clone https://github.com/launchdarkly/ios-eventsource`

#### Remove CocoaPods
2. Go to the `ios-eventsource` folder.
  * If CocoaPods is installed on your system, do the following:
    * run `pod deintegrate`.
    * Open `LDEventSource.workspace`.
    * Delete `Pods.xcodeproj` in the *Project Navigator*.
    * Close `LDEventSource.workspace`.
    * Delete `Podfile` and `Podfile.lock` from the `ios-eventsource` folder.
  * If CocoaPods is not installed on your system, do the following:
    * Delete `DarklyEventSource.podspec`, `Podfile`, `Podfile.lock` and the entire `Pods` folder.
    * Open `LDEventSource.xcodeproj`.
    * Delete the `Pods` group in the *Project Navigator*.
    * Open the `Frameworks` group in the *Project Navigator*.
    * Remove any `Pods` frameworks or static libraries from the group.
    * Select `DarklyEventSource` in the *Project Navigator*.
    * Select `DarklyEventSource-iOS` in the *Targets* pane.
    * Select the *General* tab.
    * Remove any `Pods` framework from `Linked Frameworks and Libraries`.
    * Repeat for each target, including `DarklyEventSourceTests`.
    * Select the *Build Phases* tab.
    * Remove `[CP] Check Pods Manifest.lock`.
    * Repeat for each target.
    * Close `LDEventSource.xcodeproj`.
3. Go to the `ios-client` folder.
  * If CocoaPods is installed on your system, do the following:
    * run `pod deintegrate`.  
    * Open `LaunchDarkly.workspace`.
    * Delete `Pods.xcodeproj` in the *Project Navigator*.
    * Close `LaunchDarkly.workspace`.
    * Delete `Podfile` and `Podfile.lock` from the `ios-client` folder.
  * If CocoaPods is not installed, do the following:
    * Delete `LaunchDarkly.podspec`, `Podfile`, `Podfile.lock` and the entire `Pods` folder.
    * Open `LaunchDarkly.xcodeproj`.
    * Delete the `Pods` group in the *Project Navigator*.
    * Open the `Frameworks` group in the *Project Navigator*.
    * Remove any `Pods` frameworks or static libraries from the group.
    * Select `LaunchDarkly` in the *Project Navigator*.
    * Select `LaunchDarkly_iOS` in the *Targets* pane.
    * Select the *General* tab.
    * Remove any `Pods` framework from `Linked Frameworks and Libraries`.
    * Repeat for each target.
    * Select the *Build Phases* tab.
    * Remove `[CP] Check Pods Manifest.lock`.
    * Repeat for each target, including `LaunchDarklyTests`.
    * Still in *Build Phases* tab,remove the `Run Script` build phase, and repeat for each target as well.

#### Remove Carthage
4. Go to the `ios-client`.
5. Remove `Cartfile`, `Cartfile.resolved`, and the entire `Carthage` folder.
6. Open `LaunchDarkly.xcodeproj` if needed.
7. Remove `CarthageFrameworks` in the *Project Navigator*.
8. Open `Frameworks` in the *Project Navigator*.
9. Remove all `DarklyEventSource.framework` references.
10. Close `LaunchDarkly.xcodeproj`.


#### Install LaunchDarkly using frameworks
NOTE: If you want to install LaunchDarkly without using frameworks see [Install LaunchDarkly without frameworks](#install-launchdarkly-without-frameworks) below.
11. Create a `Frameworks` folder at the root of your project.
12. For each supported platform, create a sub-folder with the platform title inside of `Frameworks`.
13. Build `DarklyEventSource.framework`
  * Open `LDEventsource.xcodeproj`.
  * Select the scheme for your app's platform.
  * Select the target device.
  * Build.
  * Open `Products` in the *Project Navigator*.
  * Ctrl-Click the `DarklyEventSource.framework` file just built.
  * Select `Show in Finder`.
  * Copy the `DarklyEventSource.framework` into the `Frameworks` sub-folder for the platform.
  * Repeat for each supported platform.
  * Close `LDEventsource.xcodeproj`.
14. Build `LaunchDarkly.framework`
  * Open `LaunchDarkly.xcodeproj`.
  * Select `LaunchDarkly` project in the *Project Navigator*.
  * Select the target for your app's platform.
  * Select the *General* tab.
  * From the Frameworks folder created previously, drag the `DarklyEventSource.framework` for the matching platform into `Linked Frameworks and Libraries`.
  * Open the *Build Settings* tab.
  * Open `Framework Search Paths`.
  * Add the path to the Frameworks sub-folder for the selected platform.
  * Build.
  * Open `Products` in the *Project Navigator*.
  * Ctrl-Click the `LaunchDarkly.framework` file just built. For non-iOS platforms be sure to select the framework containing the platform name.
  * Select `Show in Finder`.
  * Copy the `LaunchDarkly.framework` or `LaunchDarkly_<platform>` into the `Frameworks` sub-folder for the platform.
  * Repeat for each supported platform.
  * Close `LaunchDarkly.xcodeproj`.
15. Add the frameworks to your project
  * Open your project.
  * Select your project in the *Project Navigator*.
  * Select the target for your app's platform.
  * Select the *General* tab.
  * From the Frameworks folder created at step 11, drag the `DarklyEventSource.framework` and `LaunchDarkly.framework` or `LaunchDarkly_<platform>.framework` for the matching platform into `Linked Frameworks and Libraries`.
  * Remove the frameworks just added from `Linked Frameworks and Libraries`. The frameworks should remain visible in the `Frameworks` group in the *Project Navigator*.
  * Add the frameworks to the `Embedded Binaries`.
  * Repeat for each target that uses LaunchDarkly.
  * Close your project.
16. Go to [Final setup instructions](#final-setup-instructions) below.

#### Install LaunchDarkly without frameworks
17. Open your app's `.xcodeproj` or `.xcworkspace` in XCode, whichever you normally use.
18. Add 2 sub-projects to your project for `LaunchDarkly` and `DarklyEventSource`. These should be added hierarchically, with your project as the outermost project, `LaunchDarkly` nested inside your project, and `DarklyEventSource` nested inside of `LaunchDarkly`. Before you begin, make sure Xcode does not have `LaunchDarkly` or `DarklyEventSource` open in any window.
  * Ctrl-click your project in the *Project Navigator*.
  * Select `Add Files to "<yourProjectName>"...`.
  * Navigate to the `ios-client` folder.
  * Select `LaunchDarkly.xcodeproj`. Make sure it is the project file, **not** the workspace file. You should now see `LaunchDarkly.xcodeproj` nested inside your project.
  * Ctrl-click `LaunchDarkly.xcodeproj` in the *Project Navigator*.
  * Select `Add Files to "LaunchDarkly.xcodeproj"...`.
  * Navigate to the `ios-eventsource` folder.
  * Select `LDEventSource.xcodeproj`. Make sure it is the project file, **not** the workspace file. You should now see `LDEventSource.xcodeproj` nested inside the `Darkly` project.
19. Add `LaunchDarkly` to your project.
  * Select your project in the *Project Navigator*
  * Select your target in the *Targets* pane.
  * Select the `Build Phases` tab.
  * Open `Target Dependencies`.
  * Add the platform specific `LaunchDarkly_<platform>` from the `LaunchDarkly` project.
  * Repeat for each target that uses LaunchDarkly.
20. Add `DarklyEventSource` to the `LaunchDarkly` project.
  * Select the `LaunchDarkly` project in the *Project Navigator*
  * Select your platform's target in the *Targets* pane.
  * Select the `Build Phases` tab.
  * Open `Target Dependencies`.
  * Add the platform specific `DarklyEventSource_<platform>` from the `DarklyEventSource` project.
  * Repeat for each platform target that uses LaunchDarkly.
21. Go to [Final setup instructions](#final-setup-instructions) below.

#### Final setup instructions
22. Import the SDK into your code:
  * Add `@import LaunchDarkly;` (Objective-c) or `import LaunchDarkly` (Swift) to the source file that references LD classes. For non-iOS platforms, include the platform name, e.g. `import LaunchDarkly_watchOS`
23. In `Build Settings` for each target, set `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` to `Yes`.
24. Delete derived data for your project, if necessary.
25. Build your app for each target. If it fails, you may have skipped one of the steps above. Verify you have chosen the appropriate platform in each step.
26. Run your app. If the app crashes, it is likely that either the incorrect platform was installed, or the `LaunchDarkly` or `DarklyEventSource` dependencies were incorrectly added, or that you may have to set `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` to `Yes`.

Your first feature flag
-----------

1. Create a new feature flag on your dashboard

2. In your application code, use the feature’s key to check whether the flag is on for each user:

        let showFeature = LDClient.shared.variation(forKey:your-flag-key, fallback: false)
        if showFeature {
            print("Showing feature for /(user.key)")
        } else {
            print("Not showing feature for /(user.key)")
        }

Manage the feature on your dashboard — control who sees the feature without re-deploying your application!


Learn more
-----------

Check out our [documentation](http://docs.launchdarkly.com) for in-depth instructions on configuring and using LaunchDarkly. You can also head straight to the [complete reference guide for this SDK](http://docs.launchdarkly.com/docs/ios-sdk-reference).

Testing
-------

We run integration tests for all our SDKs using a centralized test harness. This approach gives us the ability to test for consistency across SDKs, as well as test networking behavior in a long-running application. These tests cover each method in the SDK, and verify that event sending, flag evaluation, stream reconnection, and other aspects of the SDK all behave correctly.

Contributing
------------

See [Contributing](https://github.com/launchdarkly/ios-client/blob/master/CONTRIBUTING.md)

About LaunchDarkly
-----------

* LaunchDarkly is a continuous delivery platform that provides feature flags as a service and allows developers to iterate quickly and safely. We allow you to easily flag your features and manage them from the LaunchDarkly dashboard.  With LaunchDarkly, you can:
    * Roll out a new feature to a subset of your users (like a group of users who opt-in to a beta tester group), gathering feedback and bug reports from real-world use cases.
    * Gradually roll out a feature to an increasing percentage of users, and track the effect that the feature has on key metrics (for instance, how likely is a user to complete a purchase if they have feature A versus feature B?).
    * Turn off a feature that you realize is causing performance problems in production, without needing to re-deploy, or even restart the application with a changed configuration file.
    * Grant access to certain features based on user attributes, like payment plan (eg: users on the ‘gold’ plan get access to more features than users in the ‘silver’ plan). Disable parts of your application to facilitate maintenance, without taking everything offline.
* LaunchDarkly provides feature flag SDKs for
    * [Java](http://docs.launchdarkly.com/docs/java-sdk-reference "Java SDK")
    * [JavaScript](http://docs.launchdarkly.com/docs/js-sdk-reference "LaunchDarkly JavaScript SDK")
    * [PHP](http://docs.launchdarkly.com/docs/php-sdk-reference "LaunchDarkly PHP SDK")
    * [Python](http://docs.launchdarkly.com/docs/python-sdk-reference "LaunchDarkly Python SDK")
    * [Python Twisted](http://docs.launchdarkly.com/docs/python-twisted-sdk-reference "LaunchDarkly Python Twisted SDK")
    * [Go](http://docs.launchdarkly.com/docs/go-sdk-reference "LaunchDarkly Go SDK")
    * [Node.JS](http://docs.launchdarkly.com/docs/node-sdk-reference "LaunchDarkly Node SDK")
    * [.NET](http://docs.launchdarkly.com/docs/dotnet-sdk-reference "LaunchDarkly .Net SDK")
    * [Ruby](http://docs.launchdarkly.com/docs/ruby-sdk-reference "LaunchDarkly Ruby SDK")
    * [iOS](http://docs.launchdarkly.com/docs/ios-sdk-reference "LaunchDarkly iOS SDK")
    * [Android](http://docs.launchdarkly.com/docs/android-sdk-reference "LaunchDarkly Android SDK")
* Explore LaunchDarkly
    * [launchdarkly.com](http://www.launchdarkly.com/ "LaunchDarkly Main Website") for more information
    * [docs.launchdarkly.com](http://docs.launchdarkly.com/  "LaunchDarkly Documentation") for our documentation and SDKs
    * [apidocs.launchdarkly.com](http://apidocs.launchdarkly.com/  "LaunchDarkly API Documentation") for our API documentation
    * [blog.launchdarkly.com](http://blog.launchdarkly.com/  "LaunchDarkly Blog Documentation") for the latest product updates
    * [Feature Flagging Guide](https://github.com/launchdarkly/featureflags/  "Feature Flagging Guide") for best practices and strategies

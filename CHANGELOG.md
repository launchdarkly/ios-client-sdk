# Change log

All notable changes to the LaunchDarkly iOS SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

## [5.3.2] - 2021-02-11
### Fixed
- Updated to prevent a crash in `dispatch_group_leave.cold.1` that would rarely occur as the SDK transitioned to an online state for a given configuration or user. This issue may have been exacerbated for a short period due to a temporary change in the behavior of the LaunchDarkly service streaming endpoint. Thanks to all the users who reported ([#235](https://github.com/launchdarkly/ios-client-sdk/issues/235)).
- Updated `LDSwiftEventSource` dependency to correct an issue where a streaming connection could sometimes reconnect after being set offline.

## [5.3.1] - 2020-12-15
### Fixed
- Decoupled `FlagStore` from `LDUser` to fix a bug where multiple environments could overwrite each other's flag values.

## [5.3.0] - 2020-11-06
### Added
- Adds to `LDConfig` the ability to dynamically configure the HTTP headers on requests through the `headerDelegate` property, which has the type `RequestHeaderTransform`.

## [5.2.0] - 2020-10-09
### Added
- `LDUser` now has an optional `secondary` attribute to match other LaunchDarkly SDKs. For more on the behavior of this attribute see [the documentation on targeting users](https://docs.launchdarkly.com/home/managing-flags/targeting-users).

### Fixed
- Corrected a bug preventing private custom attribute names being recorded in events when all custom attributes are set to be private by including "custom" in the `LDUser.privateAttributes` or `LDConfig.privateUserAttributes` properties.
- Update Nimble to 9.0 and Quick to 3.0 to fix tests when run with Swift 5.3.
- Fixes build warnings in Xcode 12.0.0.

## [5.1.0] - 2020-08-04

### Added
- The ability to specify additional headers to be included on HTTP requests to LaunchDarkly services using `LDConfig.additionalHeaders`. This feature is to enable certain proxy configurations, and is not needed for normal use.
- Support for building docs with [jazzy](https://github.com/realm/jazzy). These docs will be available through [GitHub Pages](https://launchdarkly.github.io/ios-client-sdk/).

### Fixed
- SDK causing nested bundles in archived product when including the SDK through Carthage. This caused rejections when submitted to the App Store. Thanks to @spr for reporting ([#217](https://github.com/launchdarkly/ios-client-sdk/issues/217)).
- SDK causing application to expect LDSwiftEventSource dynamic framework when built with SwiftPM, which does not include the dynamic framework in the resulting application. This causes the application to be rejected when submitted to the App Store. Thanks to @spr for reporting ([#216](https://github.com/launchdarkly/ios-client-sdk/issues/216)).

## [5.0.1] - 2020-07-23
**Note that this release contains the notes for the 5.0.0 release, which should not be used.**

This major version has an accompanying [Migration Guide](https://docs.launchdarkly.com/sdk/client-side/ios/migration-4-to-5). Please see the guide for more information on updating to this version of the SDK, as the following is just a summary of the changes.

### Added
- Support for multiple LaunchDarkly projects or environments. Each set of feature flags associated with a mobile key is called an environment. This adds:
  * `LDConfig.setSecondaryMobileKeys` and `LDConfig.getSecondaryMobileKeys` which allows configuring a mapping of names to the SDK keys for each additional environment. `LDConfig.mobileKey` is still required, and represents the primary environment.
  * `LDClient.get(environment: )` which allows retrieving an LDClient instance for a given environment after the SDK has been initialized.
  * Equivalent methods have been added to the Objective-C bindings for `LDConfig` and `LDClient`.
- The SDK now periodically sends diagnostic data to LaunchDarkly, describing the version and configuration of the SDK, the operating system the SDK is running on, the device type (such as "iPad"), and performance statistics. No credentials, device IDs, or other identifiable values are included. This behavior can be disabled or configured with the new `LDConfig` properties `diagnosticOptOut` and `diagnosticRecordingInterval`.
- The SDK can now be configured with `LDConfig.wrapperName` and `LDConfig.wrapperVersion` to send an additional header (`X-LaunchDarkly-Wrapper`) in requests to LaunchDarkly. This was added so that the usage of wrapper libraries (such as the [React Native SDK](https://github.com/launchdarkly/react-native-client-sdk)) could be recorded independently.
- Added the `evaluationReasons` field to the Objective-C bindings for `LDConfig` to allow configuring the SDK to request evaluation reasons when the application is written in Objective-C.
- The SDK now supports using the [Swift Package Manager](https://swift.org/package-manager/) to include the SDK as a dependency.
- `LDInvalidArgumentError` that is thrown on incorrect API usage.
- Added `typeMismatch` field to `ObjcLD<T>ChangedFlag` classes (bound to `LD<T>ChangedFlag` in Objective-C) that is `true`/`YES` when the flag value did not match the registered observer.

### Changed (build)
- Minimum deployment targets have been changed as follows:
  * iOS 8.0 -> 10.0
  * macOS 10.10 -> 10.12
  * tvOS 9.0 -> 10.0
  * watchOS 2.0 -> 3.0
- The SDK has replaced the internal dependency on the Objective-C eventsource implementation [DarklyEventSource](https://github.com/launchdarkly/ios-eventsource) with a pure Swift implementation [LDSwiftEventSource](https://github.com/launchdarkly/swift-eventsource). Build configurations that manually specify the DarklyEventSource dependency framework may require additional upgrade steps. See the [Migration Guide](https://docs.launchdarkly.com/sdk/client-side/ios/migration-4-to-5) for more information.
- Internally, the SDK no longer includes its dependencies using CocoaPods and Carthage. This simplifies including the SDK as a subproject of your application for integrating the SDK without a package manager.

### Changed (API)
- The `LDClient` instance method `start` has been replaced with a static method `LDClient.start` for initializing all configured environments.
- `LDChangedFlag` no longer includes the `oldValueSource` and `newValueSource` properties, as `LDFlagValueSource` was removed.
- The following were renamed for consistency internally and with other SDKs:
  * `LDClient.reportEvents()` has been renamed to `LDClient.flush()`.
  * `LDClient.stop()` has been renamed to `LDClient.close()`.
  * `LDClient.trackEvent(key: data: )` method have been renamed to `LDClient.track(key: data: )`
  * `LDClient.allFlagValues` has been renamed to `LDClient.allFlags`.
  * `EvaluationDetail` has been renamed to `LDEvaluationDetail`.
  * The `ObjC<T>EvaluationDetail` classes have been renamed to corresponding `ObjcLD<T>EvaluationDetail`. The names when exposed in Objective-C have been updated to replace the `ObjC` prefix with `LD`, e.g. `ObjCStringEvaluationDetail` to `LDStringEvaluationDetail`.
- `LDClient.track` no longer throws `JSONError` and instead throws `LDInvalidArgumentError`.
- The `fallback` parameter of all `LDClient` and `ObjcLDClient` variation methods has been renamed to `defaultValue` to help distinguish it from `fallback` values in rules specified in the LaunchDarkly dashboard.

### Changed (behavioral)
- The maximum backoff delay between failed streaming connections has been reduced from an hour to 30 seconds. This is to prevent being unable to receive new flag values for up to an hour if the SDK has reached its maximum backoff due to a period of network connectivity loss.
- The backoff on streaming connections will not be reset after just a successful connection, rather waiting for a healthy connection for one minute after receiving flags. This is to reduce congestion in poor network conditions or if extreme load prevents the LaunchDarkly service from maintaining an active streaming connection.
- When sending events to LaunchDarkly, the SDK will now retry the request after a one second delay if it fails.
- When events fail to be sent to LaunchDarkly, the SDK will no longer retain the events. This prevents double recording events when the LaunchDarkly service received the event but the SDK failed to receive the acknowledgement.
- The `LDClient.identify`, `LDClient.flush`, `LDClient.setOnline`, and `LDClient.close` instance methods now operate on all configured environments. Any completion arguments will complete when the operation has completed for all configured environments.

### Removed
- The `LDClient.shared` static property and its `ObjcLDClient.sharedInstance` wrapper property has been removed. After calling `LDClient.start`, the initialized instances can be retrieved with `LDClient.get(environment: )`.
- The `LDClient.config` and its `ObjcLDClient.config` wrapper property has been removed, configuration of the SDK should be done with `LDClient.start`.
- The `LDClient.user` and its `ObjcLDClient.user` wrapper property has been removed. The initial user should be configured with `LDClient.start`, and updates to the user should be performed with `LDClient.identify`.
- `LDFlagValueSource` and `ObjcLDFlagValueSource` were removed in favor of using `LDEvaluationDetail` and `ObjcLD<T>EvaluationDetail`.
- The Objective-C wrapper classes `ObjcLD<T>VariationValue` (bound in Objective-C to `LD<T>VariationValue`), which wrapped a flag value and its source, have been removed.
- `variationAndSource` methods were removed from `LDClient` and its `ObjcLDClient` wrapper in favor of `variationDetail` methods.
- `LDUser.init?(object: )` and corresponding `ObjcLDUser` failable initializers were removed.
- `JSONError` and `JSONErrorDomain` extensions on `JSONSerialization` were removed.
- Removed `isEqual` extension to `Array`, this was only intended for internal SDK use.
- Removed `==` and `!=` extension to `Optional<[String: Any]>` (note that this was not declared as `Equatable` conformance). This extension was only intended for internal SDK use.
- Removed `LDFlagValue` enum and the `ObjcLDFlagValue` wrapper which were exposed but not used in any public APIs.
- Removed `Sysctl` struct (only available on macOS) which was only intended for internal SDK use.

## [5.0.0] - 2020-07-23
**Please use the 5.0.1 instead. This release incorrectly specifies its version and is unavailable on CocoaPods**

## [4.7.0] - 2020-06-03
### Added
- Added a new method signature for `startCompleteWhenFlagsReceived` that accepts an additional argument specifying a maximum time to wait for flags to be received before calling the completion closure. The completion closure on this method will be passed a `Bool` on completion indication whether the operation timed out.

## [4.6.0] - 2020-05-26
### Added
- Added `maxCachedUsers` option to `LDConfig`. You can now specify the number of users to be cached or use `-1` for unlimited cached users.

### Fixed
- `FlagStore` properly synchronizes reads and writes to prevent a potential race condition.

## [4.5.0] - 2020-03-26
### Changed
- Updated SDK code to build, run, and test on Xcode 11.4.

## [4.4.1] - 2020-02-04
### Changed
- The SDK will now retry an event send once when the initial request fails.

## [4.4.0] - 2019-12-19
### Added
- Added `startCompleteWhenFlagsReceived` function which contains modified completion behavior. This new function's completion will only return after flag values are received. Previously the `start` completion returned when the SDK went online.
- The SDK now specifies a uniquely identifiable request header when sending events to LaunchDarkly to ensure that events are only processed once, even if the SDK sends them two times due to a failed initial attempt.

## [4.3.2] - 2019-12-19
### Fixed
- Flag change listeners will now be called when a flag value changes but a variation number does not change. Previously, flag listeners were not called when a value assigned to a variation was manually edited in the dashboard or via the API.

## [4.3.1] - 2019-12-12
### Changed
- Updated to `ios-eventsource` version `4.1.0`. This negates the need to `use_frameworks!` when using the React Native SDK. This change does not affect the iOS SDK.

## [4.3.0] - 2019-12-3
### Added
- Implemented `variationDetail` which returns an Evaluation Reason giving developers greater insight into why a value was returned.
- Added support for the latest Experimentation features allowing increased value from A/B/n testing. The `track` method now supports an additional `metricValue` parameter.

## [4.2.1] - 2019-11-15
### Changed
- Updated to `ios-eventsource` version `4.0.3`. This appends a platform name to bundle identifiers. (Thanks, [cswelin](https://github.com/launchdarkly/ios-eventsource/pull/28)!)

### Fixed
- Comparing two nil objects of type `[String: Any]?` no longer causes a crash. ([#197](https://github.com/launchdarkly/ios-client-sdk/issues/197))

## [4.2.0] - 2019-10-25
### Added
- The `identify` function allows a completion to be called after a user is updated.
- The Connection Status API allows greater introspection into the current LaunchDarkly connection and the health of local flags.
  • This feature adds a new class called `ConnectionInformation` that contains properties that keep track of the current connection mode e.g. streaming or polling, when and how a connection failed, and the last time flags were updated. This class can be accessed from `LDClient.shared.getConnectionInformation`.
  • Additionally, a new observer function called `observeCurrentConnectionMode` allows your application to listen to changes in the SDK's connection to LaunchDarkly.

### Changed
- The `user` property is now deprecated in favor of the `identify` function.

## [4.1.2] - 2019-07-11
### Fixed
- WatchKit is now conditionally imported in WatchOS only, to fix an error in Xcode 11.
- Comparing two nil objects of type `[String: Any]?` no longer causes a crash.

## [4.1.1] - 2019-07-09
### Changed
- Updated to `ios-eventsource` version `4.0.2`. This fixes a potential hang on LDClient start.

## [4.1.0] - 2019-06-19
### Changed
- Installs new `deviceModel` into `EnvironmentReporter` and renames old `deviceModel` to `deviceType`.
- Updated MacOS model detection to use `CwSysCtl`.

### Fixed
- Fixed a concurrency bug that caused crashes in FlagStore.swift. This bug could surface during rapid updates to local flags.

## [4.0.0] - 2019-04-18
This is the non-beta first release of the Swift SDK. It follows the beta.3 release from 2019-03-07. Unlike previous Swift SDK releases, this release does not have a `3.0.0` companion tag.
### Changed
- Changes Feature Flag caching so that cached feature flags are associated with a user key and mobile key.
- Clears new warnings that appear with Xcode 10.2

### Added
- Implements URL caching for REPORT requests.
- Installs the ability to read cached data in all cached data schemas from `2.3.3` through `3.0.1` and store the feature flags in the `4.0.0` cached data schema.
- Retains prior cached data for 90 days following upgrade to `4.0.0`. Does not keep older cached data up-to-date. Downgrading to a prior version within 90 days allows the downgraded app to read the last cached data from the downgraded version.

### Fixed
- Prevents a log message that incorrectly reported a network error on watchOS 

## [4.0.0-beta.3] - 2019-03-07
This is part of the Swift SDK beta and was originally released as  `3.0.0-beta.3`.
### Changed
- Renames SDK frameworks to `LaunchDarkly.framework` for iOS, and `LaunchDarkly_<platform>.framework` for non-iOS platforms.
- Renames targets to `LaunchDarkly_<platform>`.
- Renames project and workspace to `LaunchDarkly`
- Updates `DarklyEventSource` to version `4.0.1`
- Updates several internal dependencies to their latest versions
- Replaces `onServerUnavailable` with `observeError` on LDClient

### Added
- Instructions to integrate without a Package Manager to `README.md`
- New log entries that tell when the SDK could not find a feature flag, and when the SDK could not convert a feature flag to the requested type

## [4.0.0-beta.2] - 2019-02-06
This is part of the Swift SDK beta and was originally released as  `3.0.0-beta.2`.
### Changed
- `LDFlagValueSource` is a Swift `enum` the SDK uses to communicate the source of a feature flag (`server`, `cache`, `fallback`) to the client app. The Objective-C `enum` was changed to an object to provide Objective-C client apps access to the methods available to the enum.
- `mobileKey` was restored to a property within the `LDConfig`. As a result, `LDClient.start()` no longer takes a `mobileKey` parameter, and the `config` parameter is now required.
- `LDConfig` time-based properties (`connectionTimeout`, `eventFlushInterval`, `flagPollingInterval`, and `backgroundFlagPollingInterval`) were changed to type `TimeInterval`.
- Installs `DarklyEventSource` version `4.0.0`.
- `LDClient.trackEvent` now accepts any valid json object. If an invalid JSON object is passed, the SDK throws a `JSONSerialization.JSONError.invalidJsonObject` error at runtime.
-`LDClient.variation` and `variationAndSource` now accept Optional types and `nil` for the fallback value. The client app must specify the Optional Type for the compiler. See the migration guide for details.

## [4.0.0-beta.1] - 2018-12-11
This is part of the Swift SDK beta and was originally released as  `3.0.0-beta.1`.
### Added
- `LDClient` can now provide information about the source of a feature flag, `cache`, `server`, and `fallback`.
- `LDConfig` offers some new configuration properties: `eventCapacity`, `startOnline`, `enableBackgroundUpdates`
- `LDUser` replaces the builder model from v2.x. This Swift struct has all the v2.x properties, plus support for creating a user from a dictionary.
- `LDClient` has a new property `allFlagValues` which provides the client app with a snapshot of the feature flags available and their values

### Changed
- Replaced Objective-C SDK with Swift SDK. See [MigrationGuide.md](./MigrationGuide.md) for details on converting to v3.
- `LDConfig` and `LDUser` are Swift `struct`s, giving you value semantics which makes it easier to control the SDK.
- `LDClient` controls remain similar to v2.x. Setting a `config` or `user` is possible before, during, and after start. 
- `LDClient` uses Swift generics to get feature flag values. Swift client apps use a `variation` method (without the type) to get flag values.
- `LDClientDelegate` was removed. Observe feature flags using `observe` methods on `LDClient`. Set a closure the `LDClient` will execute when the server is unavailable.

## [3.0.1] - 2019-04-30
### Changed
- Deployed Carthage built DarklyEventSource frameworks as part of the Darkly project.

## [3.0.0] - 2019-04-17
### Changed
- Renamed the non-iOS Darkly frameworks to include the platform name. e.g. Darkly_watchOS. Because non-CocoaPods apps will need to update imports for the new modules, advanced to the next major version.
- Removed DarklyEventSource as a CocoaPods dependency in the podfile. DarklyEventSource remains a dependency in the podspec.

### Added
- Nullability specifiers for items that caused new warnings with Xcode 10.2

## [3.0.0-beta.3] - 2019-03-07
This is part of the Swift SDK beta and was renamed to `4.0.0-beta.1`. See [4.0.0-beta.3 - 2019-03-07](#4-0-0-beta-3-2019-03-07) for details

## [3.0.0-beta.2] - 2019-02-06
This is part of the Swift SDK beta and was renamed to `4.0.0-beta.2`. See [4.0.0-beta.2 - 2019-02-06](#4-0-0-beta-2-2019-02-06) for details

## [3.0.0-beta.1] - 2018-12-11
This is part of the Swift SDK beta and was renamed to `4.0.0-beta.1`. See [4.0.0-beta.1 - 2018-12-11](#4-0-0-beta-1-2018-12-11) for details

## [2.14.4] - 2019-02-26
### Changed
- Changed the following to repair macOS builds:
- Removed extraneous framework reference from Darkly_macOS target
- Deselected `Autocreate schemes` in Darkly.xcworkspace

## [2.14.3] - 2019-02-25
### Changed
- Added support for integrating without a package manager
- Updated to `DarklyEventSource` version `4.0.1`, which adds platform specific targets to support integration without a package manager.

## [2.14.2] - 2019-01-24
### Added
- Added nullability specifiers to public SDK classes.

### Changed
- Updated to `DarklyEventSource` version `4.0.0`, which eliminates a 1-second delay in SDK initialization.

## [2.14.1] - 2018-12-21
### Changed
- Added copy methods to several objects involved in creating a summary event.
- Added additional synchronization to creating a summary event in order to potentially prevent some crash scenarios.

## [2.14.0] - 2018-12-05
### Added
- Added `allFlags` property to `LDClient` that provides a dictionary of feature flag keys and values. Accessing feature flags via `allFlags` does not record any analytics events.
- Support for multiple LaunchDarkly projects or environments. Each set of feature flags associated with a mobile key is called an `environment`.
  • Added `secondaryMobileKeys` to LDConfig. LDConfig `mobileKey` refers to the *primary* environment, and must be present. All entries in `secondaryMobileKeys` refer to optional *secondary* environments.
  NOTE: See `LDClient.h` for the requirements to add `secondaryMobileKeys`. The SDK will throw an `NSInvalidArgumentException` if an attempt is made to set mobile keys that do not meet these requirements.
  • Installed `LDClientInterface` protocol used to access secondary environment feature flags. May also be used on the primary environment to provide normalized access to feature flags.
  • Adds `environmentForMobileKeyNamed:` to vend an environment (primary or secondary) object conforming to `LDClientInterface`. Use the vended object to access feature flags for the requested environment.
  • Adds new constant `kLDPrimaryEnvironmentName` used to vend the primary environment's `LDClientInterface` from `environmentForMobileKeyNamed:`.

### Changed
- `LDUserBuilder build` method no longer restores cached user attributes. The SDK sets into the `LDUserModel` object only the attributes in the `LDUserBuilder` at the time of the build message. On start, the SDK restores the last cached feature flags, which the SDK will use until the first feature flag update from the server.
- Changed the format for caching feature flags to associate a set of feature flags with a mobile key. Downgrading to an earlier version will be able to store feature flags, but without the environment association. As a result, the SDK will not restore cached feature flags from 2.14.0 if the SDK is downgraded to a version before 2.14.0.
- Installed a URL cache that does not use the `[NSURLSession defaultSession]` or the `[NSURLCache sharedURLCache]`, precluding conflicts with custom client app URL caching.

### Fixed
- Fixed defect preventing SDK from calling `userUpdated` or `featureFlagDidUpdate` when deleting a feature flag under certain conditions.
- Fixed defect preventing URL caching for feature flag requests using the `REPORT` verb.
- Fixed defect causing the loss of some analytics events when changing users.

## [2.13.9] - 2018-11-05
### Fixed
- Fixed defect causing a crash when unknown data exists in a feature flag cache.
- Renamed function parameters to avoid the use of Objective-C++ reserved words.

## [2.13.8] - 2018-10-23
### Fixed
- Fixed defect preventing feature flags cached prior to version 2.11.0 from restoring correctly and possibly crashing

## [2.13.7] - 2018-10-15
### Changed
- Initializing LDClient in polling mode no longer blocks the calling thread.

## [2.13.6] - 2018-10-05
### Fixed
- LDClient's `updateUser` did not attempt to retrieve the new user's cached flag values.
- Fixed defect preventing a user's feature flags from being cached correctly under certain conditions.

## [2.13.5] - 2018-09-23
### Changed
- Repairs Carthage build errors caused by higher fidelity checks in Xcode 10's new build engine.
- Removes `CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS` from the podspec, allowing Xcode 10's default setting to be used

## [2.13.4] - 2018-08-23
### Changed
- Update to DarklyEventSource `3.2.7`

## [2.13.3] - 2018-08-15
### Changed
- Synchronized summary event creation to limit thread access and protect data integrity
- Improved the robustness of the code creating summary events to better handle unexpected data

## [2.13.2] - 2018-07-27
### Fixed
- Updated `DarklyEventSource` in order to fix potential flag stream parsing issues.

## [2.13.1] - 2018-06-25
### Changed
- Removed early tests for reaching event capacity that caused benign Thread Sanitizer warnings
- Changed pointer nil tests to clear Static Analyzer pointer comparison warnings

## [2.13.0] - 2018-06-01
### Added
- To reduce the network bandwidth used for analytics events, feature request events are now sent as counters rather than individual events, and user details are now sent only at intervals rather than in each event. These behaviors can be modified through the LaunchDarkly UI and with the new configuration option `inlineUsersInEvents`. For more details, see [Analytics Data Stream Reference](https://docs.launchdarkly.com/v2.0/docs/analytics-data-stream-reference).
- New property `inlineUserInEvents` in `LDConfig`. When `YES` includes the full user (excluding private attributes) in analytics `feature` and `custom` events. When `NO` includes only the `userKey`. Default: `NO`.
- Calling `start` or `updateUser` (when started) on `LDClient` logs an analytics `identify` event. `identify` events contain the full user (excluding private attributes) regardless of `inlineUserInEvents`.
- Adds analytics `summary` event used to track feature flag requests to the SDK.
- Adds analytics `debug` event available to assist with debugging when requested from the website Debugger.

### Changed
- Changes analytics `feature` events so that they are only sent when requested via the website Dashboard.
- Fixed a defect preventing the SDK from updating correctly on a `put` streaming event when there are no flag changes.
- Fixed a defect on `watchOS` causing the SDK to report analytics dates incorrectly.

## [2.12.1] - 2018-04-23
### Changed
- Clears selected warnings in CocoaPods project

## [2.12.0] - 2018-04-22
### Added
- `LDClient` `isOnline` readonly property that reports the online/offline status.
- `LDClient` `setOnline` method to set the online/offline status. `setOnline` may operate asynchronously, so the client calls an optional completion block when the requested operation completes.

### Changed
- Fixed potential memory leak with `DarklyEventSource`.

### Removed
- `LDClient` `online` and `offline` methods.

### Fixed
- Calling `updateUser` on `LDClient` while streaming no longer causes the SDK to request feature flags. The SDK now disconnects from the LaunchDarkly service and reconnects with the updated user.
- Calling `updateUser` on `LDClient` while polling now resets the polling timer after making a feature flag request.

## [2.11.2] - 2018-04-06
### Changed
- Changes the minimum required `DarklyEventSource` to version `3.2.1` in the CocoaPods podspec
- The maximum backoff time for reconnecting to the feature stream is now 1 hour.

## [2.11.1] - 2018-03-26
### Changed
- Changes the minimum required `DarklyEventSource` to version `3.2.0` in the CocoaPods podspec

## [2.11.0] - 2018-03-15
### Added
- Support for enhanced feature streams, facilitating reduced SDK initialization times.

### Changed
- The `streamUrl` property on `LDConfig` now expects a path-less base URI. The default is now `"https://clientstream.launchdarkly.com"`. If you override the default, you may need to modify the property value.

## [2.10.1] - 2018-02-15
### Changed
- The minimum polling interval is now 5 minutes.

### Fixed
- Removes user flag config values from event reports
- Improves SSE connection error handling

## [2.10.0] - 2018-02-01
### Added
- Support for specifying [private user attributes](https://docs.launchdarkly.com/docs/private-user-attributes) in order to prevent user attributes from being sent in analytics events back to LaunchDarkly. See the `allUserAttributesPrivate` and `privateUserAttributes` properties of `LDConfig` as well as the `privateAttributes` property of `LDUserBuilder`.

## [2.9.1] - 2017-12-05
### Fixed
- Carthage builds no longer crash due to a missing DarklyEventSource library.

## [2.9.0] - 2017-11-29
### Changed
- `LDClientManager` no longer extends `UIApplicationDelegate`. The framework is now marked as extension-safe. Thanks @atlassian-gaustin!

### Added
- Detect 401 Unauthorized response on flag & event requests, and take the client offline when detected.
- Detect LDEventSource report of 401 Unauthorized response on connection requests, and take the client offline when detected.
- LDClient delegate method `userUnchanged` called when the client receives a feature flag update that does not change any flag keys or values.  Thanks @atlassian-gaustin!
- Xcode 9 support

### Fixed
- LDPollingManager now reads the config set at the time of the startPolling message and configures polling timers accordingly.
- LDRequestManager now reads the config set at the time of the performRequest message to configure the API request.
- Removes duplicate LDEventSource libraries linked warning
- `updateUser` now updates the `LDUser` `anonymous` property when using a default user key.

## [2.8.0] - 2017-10-13
### Added
- `useReport` property on `LDConfig` to allow switching the request verb from `GET` to `REPORT`. Do not use unless advised by LaunchDarkly.

## [2.7.0] - 2017-09-25
### Changed
- Updated for Xcode 9 support

## [2.6.1] - 2017-09-21
### Added
-`streamUrl` property on `LDConfig` to allow customizing the Server Sent Events engine in streaming mode.

## [2.6.0] - 2017-08-25
### Added
- `doubleVariation` method for `double` value feature flags, as an alternative to `numberVariation`. Thanks @atlassian-gaustin!
- `serverConnectionUnavailable` ClientDelegate method called when the LDClient receives an error response to a feature flag request. Thanks @atlassian-gaustin!

### Changed
- Prevent creating an EventSource when an EventSource is already running. Thanks @atlassian-gaustin!
- Move feature flag response processing to the request thread, and once complete return the result on the main thread. Thanks @atlassian-gaustin!

### Fixed
- Array and Dictionary flags now return the array or dictionary when available from the server instead of always returning fallback values. Thanks @atlassian-gaustin!
- Streaming no longer generates multiple feature flag requests on return to the foreground

## [2.5.1] - 2017-08-03
### Fixed
- Feature flag requests for users with non-ASCII data are now encoded correctly
- `UserUpdatedNotification` posts only when the feature flag configuration changes for the user
- Events are no longer added to the event store when capacity is reached
- Resolve potential symbol conflicts with EventSource
- Feature flag request payloads are much smaller

## [2.5.0] - 2017-07-09
### Added
- The `name` property in `LDUserBuilder`, for setting a full name. This property complements the existing `firstName` and `lastName` properties.

### Changed
- `LDConfig` has been refactored to replace the Builder pattern expected with `LDConfigBuilder`. Thanks @petrucci34!

### Deprecated
- `LDConfigBuilder` has been deprecated and will be removed in the 3.0 release.
- The `withXXX` methods of `LDUserBuilder` have been deprecated in favor of properties. These methods will be removed in the 3.0 release.

## [2.4.2] - 2017-06-20
### Fixed
- Race condition in `LDPollingManager` identified by Thread Sanitizer

## [2.4.1] - 2017-06-15
### Fixed
- Memory leak with `NSURLSession` in `EventSource`. Thanks @jimmaye!

## [2.4.0] - 2017-06-13
### Added
- The client's background fetch interval can be configured using `withBackgroundFetchInterval`.

### Changed
- By default, the client allows one background fetch per 60 minutes.

### Fixed
- Memory leak with `NSURLSession` in `LDRequestManager`. Thanks @jimmaye!
- Race condition when the client is used in multiple threads

## [2.3.3] - 2017-05-25
### Changed
- Feature flag persistence is now more efficient

### Fixed
- Client crashes if a feature flag is off and no off-variation is specified

## [2.3.2] - 2017-05-18
### Changed
- The default connection timeout is now actually 10 seconds, down from the system default of 60 seconds. Use `withConnectionTimeout` to change the setting.

### Fixed
- Potential race conditions when HTTP requests exceed 10 seconds
- HTTP requests now honor the configured connection timeout

## [2.3.1] - 2017-04-25
### Fixed
- Benign race conditions in LDRequestManager

## [2.3.0] - 2017-04-20
### Added
- Support for tvOS 9.0+
- Support for watchOS 2.0+
- Support for macOS 10.10+
- Umbrella header (`Darkly/Darkly.h`)

### Changed
- Library is now a dynamic framework in order to support the [Carthage](https://github.com/Carthage/Carthage) dependency manager
- Minimum supported iOS version is now iOS 8.0+
- Updated streaming host from `stream.launchdarkly.com` to `clientstream.launchdarkly.com`
- Default (foreground) polling interval was reduced to 5 minutes
- Minimum polling interval was reduced to 1 minute

### Fixed
- Potential range exception issue in event processing

## [2.2.0] - 2017-04-05
### Added
- Ability to disable streaming and enable interval-based polling

## [2.1.3] - 2017-04-05
### Fixed
- Uncaught exception `NSInvalidArgumentException` in `performEventRequest`

## [2.1.2] - 2017-03-20
### Added
- Backoff with jitter for connection establishment of eventsource

### Fixed
- Parity for `start` vs. `online` and `stopClient` vs. `offline`

## [2.1.1] - 2017-01-04
### Added
- Method to get notified with the flag key for which the value had changed

### Fixed
- Background fetch issues fixed

## [2.1.0] - 2016-12-19
### Changed
- Removed AFNetworking
- Code optimizations and cleanup

### Fixed
- Optimized events storage and polling algorithms
- Events generated simultaneously at the same time appear sequentially on web console without events loss

## [2.0.3] - 2016-10-26
### Changed
- Updated to use AFNetworking 3.1
- Minor code cleanup

### Fixed
- DarklyEventSource linker errors patched

## [2.0.0] - 2016-09-01
### Added
- Support for multivariate feature flags.  New methods for multivariate flags: `stringVariation`, `numberVariation`, `arrayVariation`, and `dictionaryVariation` have been added to `LDClient`.
- Support for streaming and real-time feature flag updates
- Added support for [background fetching](http://docs.launchdarkly.com/docs/ios-sdk-reference#background-fetch)

### Changed
- In `LDClient`, `toggle` value is now called `boolVariation`
- Changed 'default value' to 'fallback value' to represent the value returned if LaunchDarkly is unreachable and no previous settings are stored for the current user (no behavior changed)
- Improved ability to store multiple unique user contexts per device
- Improved support to ensure that a user receives the latest flag values even when the app is backgrounded or in airplane mode
- In `LDConfig`, `withApiKey` has been renamed to `withMobileKey`

## [1.1.0] - 2016-08-19
### Dependency update
- Removed dependency on Core Data (no interfaces or behavior changed)

## [1.0.3] - 2016-08-17
### Fixed
- Device information is included in user custom attributes in events
- Actual and default flag values are sent in Feature Request Events
- Existing flag config data is no longer sent with evaluation requests, which 
avoids `Too long request string` errors

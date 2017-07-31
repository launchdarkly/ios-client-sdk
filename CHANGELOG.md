# Change log

All notable changes to the LaunchDarkly iOS SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

## [2.5.1] - 2017-07-31
### Fixed
- Replaced base64 user encoding with base64url encoding
- userUpdatedNotification from being posted at every feature flag response
- Prevent adding an event to the event store after store capacity reached
- Resolve potential name conflicts with EventSource
- Remove user config and extraneous elements from user encoding in feature flag requests

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

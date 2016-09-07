# Change log

All notable changes to the LaunchDarkly Python SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

## [2.0.0] - 2016-09-01
### Added
- Support for multivariate feature flags.  New methods for multivariate flags: `stringVariation`, `numberVariation`, `arrayVariation`, and `dictionaryVariation` have been added to `LDClient`.
- Support for streaming and real-time feature flag updates
- Added support for [background fetching](http://docs.launchdarkly.com/docs/ios-sdk-reference#background-fetch)

### Changed
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

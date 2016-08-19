# Change log

All notable changes to the LaunchDarkly Python SDK will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org).

## [1.1.1] - 2016-08-19
### Dependency update
- Removed dependency on Core Data (no interfaces or behavior changed)

## [1.0.3] - 2016-08-17
### Fixed
- Device information is included in user custom attributes in events
- Actual and default flag values are sent in Feature Request Events
- Existing flag config data is no longer sent with evaluation requests, which 
avoids `Too long request string` errors

LaunchDarkly Migration Guide for the iOS Swift SDK
==================================================

# Getting Started
## Migration Steps
1. Integrate the v3.0.0 SDK into your app using either CocoaPods or Carthage
2. Clean, and delete Derived Data
3. Update imports to `LaunchDarkly`
4. Update `LDConfig` and properties
5. Update `LDUser` and properties
6. Update `LDClient` Controls
7. Update `LDClient` Feature Flag access
8. Install `LDClient` Observers
9. Remove `LDClientDelegate` methods.
---
## API Differences from v2.x
This section details the changes between the v2.x and v3.0.0 APIs.

### Multiple Environments
Version 3.0.0 does not support multiple environments. If you use version 2.14.0 or later and set LDConfig's `secondaryMobileKeys` you will not be able to migrate to version 3.0.0. Multiple Environments will be added in a future release to the Swift SDK.

### Configuration with LDConfig
LDConfig has changed to a `struct`, and therefore uses value semantics.

#### Changed `LDConfig` Properties
##### `mobileKey`
LDConfig no longer contains a mobileKey. Instead, pass the mobileKey into LDClient's `start` method.
##### URL properties (`baseUrl`, `eventsUrl`, and `streamUrl`)
These properties have changed to `URL` objects. Set these properties by converting URL strings to a URL using:
```swift
    ldconfig.baseUrl = URL(string: "https://custom.url.string")!
```
##### `capacity`
This property has changed to `eventCapacity`.
##### Time based properties (`connectionTimeout`, `flushInterval`, `pollingInterval`, and `backgroundFetchInterval`)
These properties have changed to `Int` properties representing milliseconds. The names have changed by appending `Millis` to the v2.x names.
##### `streaming`
This property has changed to `streamingMode` and to an enum type `LDStreamingMode`. The default remains `.streaming`. To set polling mode, set this property to `.polling`.
##### `debugEnabled`
This property has changed to `debugMode`.

#### New `LDConfig` Properties and Methods
##### `enableBackgroundUpdates`
Set this property to `true` to allow the SDK to poll while running in the background.

**NOTE**: Background polling requires additional client app support.
##### `startOnline`
Set this property to `false` if you want the SDK to remain offline after you call `start()`
##### `Minima`
We created the Minima struct and defined polling and background polling minima there. This allows the client app to ensure the values set into the corresponding properties meet the requirements for those properties. Access these via the `minima` property on your LDConfig struct.
##### `==`
LDConfig conforms to `Equatable`.

#### `LDConfig` Objective-C Compatibility
Since Objective-C does not represent `struct` items, the SDK wraps the LDConfig into a `NSObject` based wrapper with all the same properties as the Swift `struct`. The class `ObjcLDConfig` encapsulates the wrapper class. Objective-C client apps should refer to `LDConfig` and allow the Swift runtime to handle the conversion.
The type changes mentioned above all apply to the Objective-C LDConfig. `Int` types become `NSInteger` types in Objective-C, replacing `NSNumber` objects from v2.x.
An Objective-C `isEqual` method provides LDConfig object comparison capability.

### Custom users with `LDUser`
`LDUser` replaces `LDUserBuilder` and `LDUserModel` from v2.x. `LDUser` is a Swift `struct`, and therefore uses value semantics.
#### Changed `LDUser` Properties
Since the only required property is `key`, all other properties are Optional. While this is not really a change from v2.x, it is more explicit in Swift and may require some Optional handling that was not required in v2.x.
##### `ip`
This property has changed to `ipAddress`.
##### `customDictionary`
This property has changed to `custom` and its type has also changed slightly to [String: Any]?.

#### New `LDUser` Properties and Methods
##### `CodingKeys`
We added coding keys for all of the user properties. If you add your own custom attributes, you might want to extend `CodingKeys` to include your custom attribute keys.
##### `privatizableAttributes`
This new static property contains a `[String]` with the attributes that can be made private. This list is used if the LDConfig has the flag `allUserAttributesPrivate` set.
##### `device`
The SDK sets this property with the system provided device string.
##### `operatingSystem`
The SDK sets this property with the system provided operating system string.
##### `init(object:)` and `init(userDictionary:)`
These methods allows you to pass in a `[String: Any]` to create a user. Any other object passed in returns a `nil`. Use the `CodingKeys` to set user properties in the dictionary.
##### `==`
LDUser conforms to `Equatable`.

#### `LDUser` Objective-C Compatibility
Since Objective-C does not represent `struct` items, the SDK wraps the LDUser into a `NSObject` based wrapper with all the same properties as the Swift `struct`. The class `ObjcLDUser` encapsulates the wrapper class. Objective-C client apps should refer to `LDUser` and allow the Swift runtime to handle the conversion.
An Objective-C `isEqual` method provides LDConfig object comparison capability.
##### `CodingKeys`
Since `CodingKeys` is not accessible to Objective-C, we defined class vars for attribute names, allowing you to define a user dictionary that you can pass into constructors.
##### Constructors
The new constructors added to Swift were translated to Objective-C also. Use `[[LDUser alloc] initWithObject:]` and `[[LDUser alloc] initWithUserDictionary:]` to access them.
##### `isEqual`
An Objective-C `isEqual` method provides `LDUser` object comparison capability.

### `LDClient` Controls
#### Changed `LDClient` Properties & Methods
##### `sharedInstance`
This property has changed to `shared`.
##### `ldUser`
This property has changed to `user` and its type has changed to `LDUser`. Client apps can set the `user` directly.
##### `ldConfig`
This property has changed to `config`. Client apps can set the `config` directly.
##### `delegate`
This property was removed. See [Replacing LDClient delegate methods](#replacing-ld-client-delegate)
##### `start`
- This method has a new `mobileKey` first parameter.
- `inputConfig` has changed to `config`.
- `withUserBuilder` has changed to `user` and its type changed to `LDUser`
- `completion` was added to get a callback when the SDK has completed starting
##### `stopClient`
This method was renamed to `stop()`

#### New `LDClient` Properties
##### `onServerUnavailable()`
This property sets a closure called when the SDK is unable to contact the LaunchDarkly servers. The SDK keeps a strong reference to this closure. Remove this closure from the client before the owning object goes out of scope.

#### Objective-C `LDClient` Compatibility
`LDClient` does not inherit from NSObject, and is therefore not directly available to Objective-C. Instead, the class `ObjcLDClient` wraps the LDClient. Since the wrapper inherits from NSObject, Objective-C apps can access the LDClient. We have defined the Objective-C name for `ObjcLDClient` to `LDClient`, so you access the client through `LDClient` just as before.

`shared` isn't used with Objective-C, continue to use `sharedInstance`.

### Getting Feature Flag Values
#### `variation()`
Swift Generics allowed us to combine the `variation` methods that were used in the v2.x SDK. v3.0.0 has a single `variation` method that returns a type that matches the type the client app provides in the `fallback` parameter.
#### `variationAndSource()`
A new `variationAndSource()` method returns a tuple `(value, source)` that allows the client app to see what the source of the value was. `source` is an `LDFlagValueSource` enum with `.server`, `.cache`, and `.fallback`.
#### `allFlagValues`
A new computed property `allFlagValues` returns a `[LDFlagKey: Any]` that has all feature flag keys and their values. This dictionary is a snapshot taken when `allFlagValues` was requested. The SDK does not try to keep these values up-to-date, and does not record any events when accessing the dictionary.
#### Objective-C Feature Flag Value Compatibility
Swift generic functions cannot operate in Objective-C. The `ObjcLDClient` wrapper retains the type-based variation methods used in v2.x.

The wrapper also includes new type-based `variationAndSource` methods that return a type-based `VariationValue` object (e.g. `LDBoolVariationValue`) that encapsulates the `value` and `source`. `source` is an `ObjcLDFlagValueSource` Objective-C int backed enum (accessed in Objective-C via `LDFlagValueSource`). In addition to `server`, `cache`, and `fallback`, `nilSource`, and `typeMismatch` could be possible values.

### Monitoring Feature Flags for changes
v3.0.0 removes the `LDClientDelegate`, which included `featureFlagDidUpdate` and `userDidUpdate` that the SDK called to notify client apps of changes in the set of feature flags for a given mobile key (called the environment). In order to have the SDK notify the client app when feature flags change, we have provided a closure based observer API.
#### Single-key `observe()`
To monitor a single feature flag, set a callback handler using `observe(key:, owner:, handler:)`. The SDK will keep a weak reference to the `owner`. When an observed feature flag changes, the SDK executes the closure, passing into it an `LDChangedFlag` that provides the `key`, `oldValue`, `oldValueSource`, `newValue`, and `newValueSource`. The client app can use this to update itself with the new value, or use the closure as a trigger to make another `variation` request from the LDClient.
#### Multiple-key `observe()`
To monitor a set of feature flags, set a callback handler using `observe(keys: owner: handler:)`. This functions similar to the single feature flag observer. When any of the observed feature flags change, the SDK will call the closure one time. The closure takes a `[LDFlagKey: LDChangedFlag]` which the client app can use to update itself with the new values.
#### All-Flags `observeAll()`
To monitor all feature flags in an environment, set a callback handler using `observeAll()`. This functions similar to the multiple-key feature flag observer. When any feature flag in the environment changes, the SDK will call the closure one time.
#### `observeFlagsUnchanged()`
To monitor when a polling request completes with no changes to the environment, set a callback handler using `observeFlagsUnchanged()`. If the SDK is in `.polling` mode, and a flag request did not change any flag values, the SDK will call this closure. (NOTE: In `.streaming` mode, there is no event that signals flags are unchanged. Therefore this callback will be ignored in `.streaming` mode). This method effectively replaces the LDClientDelegate method `userUnchanged`.
#### `stopObserving()`
To discontinue monitoring all feature flags for a given object, call this method. Note that this is not required, the SDK will only keep a weak reference to observers. When the observer goes out of scope, the SDK reference will be nil'd out, and the SDK will no longer call that handler.
#### Objective-C Observer Support
The LDClient wrapper provides type-based single-key observer methods that function as described above. The only difference is that the object passed into the observer block will contain type-based Objective-C wrappers for `LDChangedFlag`. `observeKeys` provides multiple-key observing, and `observeAllKeys` provides all-key observing. These function as described above, except that the dictionary passed into the handler will contain Objective-C type-based wrappers that encapsulate the LDChangedFlag properties.

### Event Controls
#### Changed Event Controls
##### `flush`
This method has changed to `reportEvents()`.
##### `track`
This method has changed to `trackEvent`

## Replacing LDClient delegate methods
### `featureFlagDidUpdate` and `userDidUpdate`
The `observe` methods provide the ability to monitor feature flags individually, as a collection, or the whole environment. The SDK will release these observers when they go out of scope, so you can set and forget them. Of course if you need to stop observing you can do that also.
### `userUnchanged`
The `observeFlagsUnchanged` method sets an observer called in `.polling` mode when a flag request leaves the flags unchanged, effectively replacing `userUnchanged`.
### `onServerUnavailable`
This property sets a closure the SDK will execute if it cannot connect to LaunchDarkly's servers, effectively replacing `serverConnectionUnavailable`. Only 1 closure can be set at a time, and the SDK keeps a strong reference to that closure.

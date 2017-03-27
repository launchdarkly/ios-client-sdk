LaunchDarkly SDK for iOS
========================

![CircleCI](https://circleci.com/gh/launchdarkly/ios-client.svg?branch=master)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/LaunchDarkly.svg)](https://img.shields.io/cocoapods/v/DarklyEventSource.svg)

Why did we fork this SDK?
-----------
We want to make this an even better client SDK and have a couple of suggestions to do so:

### Software Engineering Best Practices
There is a well-known heuristic called the [Law of Demeter](https://en.wikipedia.org/wiki/Law_of_Demeter) that says a module should not know about the innards of the objects it manipulates. This means that an object should not expose its internal structure through accessors because to do so is to expose, rather than to hide, its internal structure. The accessors in `LDUserBuilder` ignore this principle and return a reference to the object itself eg. 

```
- (LDUserBuilder *)withKey:(NSString *)key;
- (LDUserBuilder *)withFirstName:(NSString *)firstName;
- (LDUserBuilder *)withLastName:(NSString *)lastName;
- (LDUserBuilder *)withEmail:(NSString *)email;
...
```

The API suggests the following usage:

```
 // Objective-C
 LDUserBuilder *user = [[LDUserBuilder alloc] init];
 user = [user withKey:@"aa0ceb"];
 user = [user withFirstName:@"Bob"];
 user = [user withLastName:@"Jones"];
 user = [user withEmail:@"bobjones@email.com"];
 
 // Swift
 var user = LDUserBuilder()
 user = user.withKey("aa0ceb")
 user = user.withFirstName("Bob")
 user = user.withLastName("Jones")
 user = user.withEmail("bobjones@email.com")
```

or worse yet:

```
 // Objective-C
 LDUserBuilder *user = [[LDUserBuilder alloc] init];
 user = [[[[user withKey:@"aa0ceb"] withFirstName:@"Bob"] withLastName:@"Jones" withEmail:@"bobjones@email.com"];
 
 // Swift
 var user = LDUserBuilder()
 user = user.withKey("aa0ceb").withFirstName("Bob").withLastName("Jones").withEmail("bobjones@email.com")
```

This usage has multiple problems. These methods should not invoke methods on objects that are returned by any of the allowed functions. This kind of code is often called a [train wreck](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882) because it look like a bunch of coupled train cars. Chains of calls like this are generally considered to be sloppy style and should be avoided. It is usually best to split them up as follows:

```
- (void)setKey:(NSString *)key;
- (void)setFirstName:(NSString *)firstName;
- (void)setLastName:(NSString *)lastName;
- (void)setEmail:(NSString *)email;

 // Objective-C
 LDUserBuilder *user = [[LDUserBuilder alloc] init];
 [user setKey:@"aa0ceb"];
 [user setFirstName:@"Bob"];
 [user setLastName:@"Jones"];
 [user setEmail:@"bobjones@email.com"];
 
 // Swift
 let user = LDUserBuilder()
 user.setKey("aa0ceb")
 user.setFirstName("Bob")
 user.setLastName("Jones")
 user.setEmail("bobjones@email.com")
```

Notice that in Swift, `user` can now be declared as a `let` constant instead of a `var` since we're no longer assigning to it.

Better yet, these attributes can be declared as first-class properties. After all, the implementation barely sets the internal vars to the new values eg.

```
@property (nonatomic, copy, nullable) NSString *key;
@property (nonatomic, copy, nullable) NSString *firstName;
@property (nonatomic, copy, nullable) NSString *lastName;
@property (nonatomic, copy, nullable) NSString *email;
```

This has the added benefit of the code matching the documentation ie. a property mentioned as being optional is `nullable`.


### Cocoa Guidelines
While the code works, in places it does not conform to Cocoa guidelines.

* Objective-C no longer requires ivars to be declared separately eg. the below code is redundant:

```
@interface LDUserBuilder() {
    NSString *key;
    NSString *ip;
    NSString *country;
    NSString *firstName;
    NSString *lastName;
    NSString *email;
    NSString *avatar;
    NSMutableDictionary *customDict;
    BOOL anonymous;
}
```

as Objective-C runtime generates the ivars automatically.


* Objective-C doesn't use the C-style pointer operator `->` eg. the below code is not Objective-C:

```
    if (iBuilder->key) {
        [iUser key:iBuilder->key];
    }
```

It should be re-written as:

```
    if ([iBuilder key]) {
        [iUser key:[iBuilder key]];
    }
```
 
Or better yet using the `.` operator:


```
    if (iBuilder.key) {
        iUser.key = iBuilder.key;
    }
``` 

* Cocoa naming guidelines discourage using `get`, `retrieve` etc as method names that return a property. The convention is to just use the property name eg.

```
+ (LDUserBuilder *)retrieveCurrentBuilder:(LDUserModel *)iUser;
```

becomes:

```
+ (LDUserBuilder *)currentBuilder:(LDUserModel *)iUser;
```

* Objective- 2.0 syntax to access dictionary and array elements eg.

```
[customDict setObject:value forKey:inputKey];
```

becomes:

```
self.customDictiionary[inputKey] = value;
```

We believe that with the suggested changes, the SDK will become more modern and reliable.




Quick setup
-----------

1. Add the SDK to your `Podfile`:

        pod `LaunchDarkly`

2. Import the LaunchDarkly client:

        #import "LDClient.h"

3. Instantiate a new LDClient with your mobile key and user:

        LDConfigBuilder *config = [[LDConfigBuilder alloc] init];
        [config withMobileKey:@"YOUR_MOBILE_KEY"];
    
        LDUserBuilder *user = [[LDUserBuilder alloc] init];
        user = [user withKey:@"aa0ceb"];
    
        [[LDClient sharedInstance] start:config userBuilder:user];

(Be sure to use a mobile key from your environments. Never embed a standard SDK key into a mobile application.)

Your first feature flag
-----------

1. Create a new feature flag on your dashboard

2. In your application code, use the feature’s key to check whether the flag is on for each user:

        BOOL showFeature = [[LDClient sharedInstance] boolVariation:@"YOUR_FLAG_KEY" fallback:NO];
        if (showFeature) {
                NSLog(@"Showing feature for %@", user.key);
        } else {
                NSLog(@"Not showing feature for user %@", user.key);
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
    * [JavaScript] (http://docs.launchdarkly.com/docs/js-sdk-reference "LaunchDarkly JavaScript SDK")
    * [PHP] (http://docs.launchdarkly.com/docs/php-sdk-reference "LaunchDarkly PHP SDK")
    * [Python] (http://docs.launchdarkly.com/docs/python-sdk-reference "LaunchDarkly Python SDK")
    * [Python Twisted] (http://docs.launchdarkly.com/docs/python-twisted-sdk-reference "LaunchDarkly Python Twisted SDK")
    * [Go] (http://docs.launchdarkly.com/docs/go-sdk-reference "LaunchDarkly Go SDK")
    * [Node.JS] (http://docs.launchdarkly.com/docs/node-sdk-reference "LaunchDarkly Node SDK")
    * [.NET] (http://docs.launchdarkly.com/docs/dotnet-sdk-reference "LaunchDarkly .Net SDK")
    * [Ruby] (http://docs.launchdarkly.com/docs/ruby-sdk-reference "LaunchDarkly Ruby SDK")
    * [iOS] (http://docs.launchdarkly.com/docs/ios-sdk-reference "LaunchDarkly iOS SDK")
    * [Android] (http://docs.launchdarkly.com/docs/android-sdk-reference "LaunchDarkly Android SDK")
* Explore LaunchDarkly
    * [launchdarkly.com] (http://www.launchdarkly.com/ "LaunchDarkly Main Website") for more information
    * [docs.launchdarkly.com] (http://docs.launchdarkly.com/  "LaunchDarkly Documentation") for our documentation and SDKs
    * [apidocs.launchdarkly.com] (http://apidocs.launchdarkly.com/  "LaunchDarkly API Documentation") for our API documentation
    * [blog.launchdarkly.com] (http://blog.launchdarkly.com/  "LaunchDarkly Blog Documentation") for the latest product updates
    * [Feature Flagging Guide] (https://github.com/launchdarkly/featureflags/  "Feature Flagging Guide") for best practices and strategies

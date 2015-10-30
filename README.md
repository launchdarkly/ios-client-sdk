LaunchDarkly SDK for iOS
========================

Quick setup
-----------

1. Add the SDK to your `Podfile`:

        pod `LaunchDarkly`

2. Import the LaunchDarkly client:

        #import "LDClient.h"

3. Instantiate a new LDClient with your mobile API key:

        LDConfigBuilder *config = [[LDConfigBuilder alloc] init];
        [config withApiKey:@"YOUR_MOBILE_KEY"];
    
        [[LDClient sharedInstance] start:config];


Learn more
-----------

Check out our [documentation](http://docs.launchdarkly.com) for in-depth instructions on configuring and using LaunchDarkly. You can also head straight to the [complete reference guide for this SDK](http://docs.launchdarkly.com/v1.0/docs/ios-sdk-reference).
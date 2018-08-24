
#import "RNLaunchDarkly.h"
#import "DarklyConstants.h"

@implementation RNLaunchDarkly

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"FeatureFlagChanged"];
}

RCT_EXPORT_METHOD(configure:(NSString*)apiKey options:(NSDictionary*)options) {
    NSLog(@"configure with %@", options);

    NSString* key           = options[@"key"];
    NSString* firstName     = options[@"firstName"];
    NSString* lastName      = options[@"lastName"];
    NSString* email         = options[@"email"];
    NSNumber* isAnonymous   = options[@"isAnonymous"];
    NSString* organization   = options[@"organization"];

    LDConfigBuilder *config = [[LDConfigBuilder alloc] init];
    [config withMobileKey:apiKey];

    LDUserBuilder *user = [[LDUserBuilder alloc] init];
    user = [user withKey:key];

    if (firstName) {
        user = [user withFirstName:firstName];
    }

    if (lastName) {
        user = [user withLastName:lastName];
    }

    if (email) {
        user = [user withEmail:email];
    }

    if (organization) {
        user = [user withCustomString:@"organization" value:organization];
    }

    if([isAnonymous isEqualToNumber:[NSNumber numberWithBool:YES]]) {
        user = [user withAnonymous:TRUE];
    }

    if ( self.user ) {
        [[LDClient sharedInstance] updateUser:user];
        return;
    }

    self.user = [user build];

    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handleFeatureFlagChange:)
     name:kLDFlagConfigChangedNotification
     object:nil];

    [[LDClient sharedInstance] start:config userBuilder:user];
}

RCT_EXPORT_METHOD(boolVariation:(NSString*)flagName callback:(RCTResponseSenderBlock)callback) {
    BOOL showFeature = [[LDClient sharedInstance] boolVariation:flagName fallback:NO];
    callback(@[[NSNumber numberWithBool:showFeature]]);
}

RCT_EXPORT_METHOD(stringVariation:(NSString*)flagName fallback:(NSString*)fallback callback:(RCTResponseSenderBlock)callback) {
    NSString* flagValue = [[LDClient sharedInstance] stringVariation:flagName fallback:fallback];
    callback(@[flagValue]);
}

- (void)handleFeatureFlagChange:(NSNotification *)notification
{
    NSString *flagName = notification.userInfo[@"flagkey"];
    [self sendEventWithName:@"FeatureFlagChanged" body:@{@"flagName": flagName}];
}

RCT_EXPORT_MODULE()

@end


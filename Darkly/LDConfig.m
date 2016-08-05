//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "LDUtil.h"

@implementation LDConfig

@synthesize mobileKey, baseUrl, capacity, connectionTimeout, flushInterval, debugEnabled;

@end

@interface LDConfigBuilder() {
    NSString *mobileKey;
    NSString *baseUrl;
    NSNumber *capacity;
    NSNumber *connectionTimeout;
    LDUserModel * userModel;
    NSNumber *flushInterval;
    BOOL debugEnabled;
}

@end

@implementation LDConfigBuilder

- (LDConfigBuilder *)withMobileKey:(NSString *)inputMobileKey
{
    mobileKey = inputMobileKey;
    return self;
}

- (LDConfigBuilder *)withUserModel:(LDUserModel *)inputUserModel
{
    userModel = inputUserModel;
    return self;
}

- (LDConfigBuilder *)withBaseUrl:(NSString *)inputBaseUrl
{
    baseUrl = inputBaseUrl;
    return self;
}

- (LDConfigBuilder *)withCapacity:(int)inputCapacity
{
    capacity = [NSNumber numberWithInt:inputCapacity];
    return self;
}

- (LDConfigBuilder *)withConnectionTimeout:(int)inputConnectionTimeout
{
    connectionTimeout = [NSNumber numberWithInt:inputConnectionTimeout];
    return self;
}

- (LDConfigBuilder *)withFlushInterval:(int)inputFlushInterval
{
    flushInterval = [NSNumber numberWithInt:inputFlushInterval];
    return self;
}

- (LDConfigBuilder *)withDebugEnabled:(BOOL)inputDebugEnabled
{
    debugEnabled = inputDebugEnabled;
    return self;
}

-(LDConfig *)build
{
    DEBUG_LOGX(@"LDConfigBuilder build method called");
    LDConfig *config = [[LDConfig alloc] init];
    if (mobileKey) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with mobileKey: %@", mobileKey);
        [config setMobileKey:mobileKey];
    } else {
        DEBUG_LOGX(@"LDConfigBuilder requires an MobileKey");
        return nil;
    }
    
    NSData *userData = [NSKeyedArchiver archivedDataWithRootObject:userModel];
    NSString *base64UserString = [userData base64EncodedStringWithOptions:0];
    
    if (baseUrl) {
        NSString *userAppendedURL = [NSString stringWithFormat:@"%@/%@",baseUrl,base64UserString];
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with baseUrl: %@", userAppendedURL);
        [config setBaseUrl:userAppendedURL];
    } else {
        NSString *userAppendedURL = [NSString stringWithFormat:@"%@/%@",kBaseUrl,base64UserString];
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default baseUrl: %@", userAppendedURL);
        [config setBaseUrl:userAppendedURL];
    }
    if (capacity) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with capacity: %@", capacity);
        [config setCapacity:capacity];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default capacity: %d", kCapacity);
        [config setCapacity:[NSNumber numberWithInt:kCapacity]];
    }
    if (connectionTimeout) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with timeout: %@", connectionTimeout);
        [config setConnectionTimeout:connectionTimeout];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default timeout: %d", kConnectionTimeout);
        [config setConnectionTimeout:[NSNumber numberWithInt:kConnectionTimeout]];
    }
    if (flushInterval) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with flush interval: %@", flushInterval);
        [config setFlushInterval:flushInterval];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default flush interval: %d", kDefaultFlushInterval);
        [config setFlushInterval:[NSNumber numberWithInt:kDefaultFlushInterval]];
    }
    if (debugEnabled) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with debug enabled: %d", debugEnabled);
        [config setDebugEnabled:debugEnabled];
    }
    return config;
}

@end
//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDConfig.h"
#import "LDUtil.h"

@implementation LDConfig

@synthesize apiKey, baseUrl, capacity, connectionTimeout, flushInterval, debugEnabled;

@end

@interface LDConfigBuilder() {
    NSString *apiKey;
    NSString *baseUrl;
    NSNumber *capacity;
    NSNumber *connectionTimeout;
    NSNumber *flushInterval;
    BOOL debugEnabled;
}

@end

@implementation LDConfigBuilder

- (LDConfigBuilder *)withApiKey:(NSString *)inputApiKey
{
    apiKey = inputApiKey;
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
    if (apiKey) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with apiKey: %@", apiKey);
        [config setApiKey:apiKey];
    } else {
        DEBUG_LOGX(@"LDConfigBuilder requires an ApiKey");
        return nil;
    }
    if (baseUrl) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with baseUrl: %@", baseUrl);
        [config setBaseUrl:baseUrl];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default baseUrl: %@", kBaseUrl);
        [config setBaseUrl:kBaseUrl];
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
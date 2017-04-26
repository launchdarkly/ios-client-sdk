//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "LDUtil.h"

@interface LDConfig()
@property (nonatomic, copy, nonnull) NSString* mobileKey;
@end

@implementation LDConfig

- (instancetype)initWithMobileKey:(NSString *)mobileKey {
    if (!(self = [super init])) {
        return nil;
    }

    self.mobileKey = mobileKey;

    return self;
}

@end

@interface LDConfigBuilder()
@property (nonnull, strong) LDConfig *config;
@end

@implementation LDConfigBuilder

- (instancetype)initWithConfig:(LDConfig *)config {
    if (!(self = [super init])) {
        return nil;
    }

    self.config = config;
    self.streaming = YES;

    return self;
}

- (id)init {
    self = [super init];
    streaming = YES;
    return self;
}

- (LDConfigBuilder *)withMobileKey:(NSString *)inputMobileKey
{
    mobileKey = inputMobileKey;
    return self;
}

- (LDConfigBuilder *)withBaseUrl:(NSString *)inputBaseUrl
{
    baseUrl = inputBaseUrl;
    return self;
}

-(LDConfigBuilder *)withEventsUrl:(NSString *)inputEventsUrl{
    eventsUrl = inputEventsUrl;
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

- (LDConfigBuilder *)withPollingInterval:(int)inputPollingInterval
{
    pollingInterval = [NSNumber numberWithInt:MAX(inputPollingInterval, kMinimumPollingInterval)];
    return self;
}

- (LDConfigBuilder *)withStreaming:(BOOL)inputStreamingEnabled
{
    streaming = inputStreamingEnabled;
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
    if (baseUrl) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with baseUrl: %@", baseUrl);
        [config setBaseUrl:baseUrl];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default baseUrl: %@", kBaseUrl);
        [config setBaseUrl:kBaseUrl];
    }
    if (eventsUrl) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with eventsUrl: %@", eventsUrl);
        [config setEventsUrl:eventsUrl];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default eventsUrl: %@", kEventsUrl);
        [config setEventsUrl:kEventsUrl];
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
    if (pollingInterval) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with polling interval: %@", pollingInterval);
        [config setPollingInterval:pollingInterval];
    } else {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with default polling interval: %d", kDefaultPollingInterval);
        [config setPollingInterval:[NSNumber numberWithInt:kDefaultPollingInterval]];
    }
    
    DEBUG_LOG(@"LDConfigBuilder building LDConfig with streaming enabled: %d", streaming);
    [config setStreaming:streaming];
    
    if (debugEnabled) {
        DEBUG_LOG(@"LDConfigBuilder building LDConfig with debug enabled: %d", debugEnabled);
        [config setDebugEnabled:debugEnabled];
    }
    return config;
}

@end

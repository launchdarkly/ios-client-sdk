//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "LDUtil.h"
#import "LDClient.h"
#import "NSString+LaunchDarkly.h"
#import "NSDictionary+LaunchDarkly.h"

@interface LDConfig()
@property (nonatomic, copy, nonnull) NSString* mobileKey;
@property (nonatomic, strong, nonnull) NSArray<NSNumber*> *flagRetryStatusCodes;
@end

@implementation LDConfig

- (instancetype)initWithMobileKey:(NSString *)mobileKey {
    if (!(self = [super init])) {
        return nil;
    }

    self.mobileKey = mobileKey;
    self.streaming = YES;
    self.capacity = [NSNumber numberWithInt:kCapacity];
    self.connectionTimeout = [NSNumber numberWithInt:kConnectionTimeout];
    self.flushInterval = [NSNumber numberWithInt:kDefaultFlushInterval];
    self.pollingInterval = [NSNumber numberWithInt:kDefaultPollingInterval];
    self.backgroundFetchInterval = [NSNumber numberWithInt:kDefaultBackgroundFetchInterval];
    self.baseUrl = kBaseUrl;
    self.eventsUrl = kEventsUrl;
    self.streamUrl = kStreamUrl;
//    self.flagRetryStatusCodes = @[@(kHTTPStatusCodeMethodNotAllowed),
//                                  @(kHTTPStatusCodeBadRequest),
//                                  @(kHTTPStatusCodeNotImplemented)];
    self.flagRetryStatusCodes = @[];    //Temporarily, leave these codes empty to disable the REPORT fallback using GET capability
    self.useReport = NO;
    self.allUserAttributesPrivate = NO;

    return self;
}

- (void)setMobileKey:(NSString *)mobileKey {
    _mobileKey = [mobileKey copy];
    DEBUG_LOG(@"Set LDConfig mobileKey: %@", mobileKey);
}

- (void)setSecondaryMobileKeys:(NSDictionary<NSString *,NSString *> *)secondaryMobileKeys {
    if ([secondaryMobileKeys.allKeys containsObject:kLDPrimaryEnvironmentName]) {
        NSException *invalidConfigException =
            [NSException exceptionWithName:NSInvalidArgumentException reason:@"Illegal LDConfig secondaryMobileKeys: May not contain the primary environment name." userInfo:nil];
        @throw invalidConfigException;
    }
    if ([secondaryMobileKeys.allValues containsObject:self.mobileKey]) {
        NSException *invalidConfigException =
            [NSException exceptionWithName:NSInvalidArgumentException reason:@"Illegal LDConfig secondaryMobileKeys: May not contain the primary mobile key." userInfo:nil];
        @throw invalidConfigException;
    }
    if ([NSSet setWithArray:secondaryMobileKeys.allValues].count != secondaryMobileKeys.allValues.count) {
        NSException *invalidConfigException =
            [NSException exceptionWithName:NSInvalidArgumentException reason:@"Illegal LDConfig secondaryMobileKeys: mobile keys must all be unique" userInfo:nil];
        @throw invalidConfigException;
    }
    if ([secondaryMobileKeys.allKeys containsObject:@""]) {
        NSException *invalidConfigException =
        [NSException exceptionWithName:NSInvalidArgumentException reason:@"Illegal LDConfig secondaryMobileKeys: May not contain an empty environment name." userInfo:nil];
        @throw invalidConfigException;
    }
    if ([secondaryMobileKeys.allValues containsObject:@""]) {
        NSException *invalidConfigException =
        [NSException exceptionWithName:NSInvalidArgumentException reason:@"Illegal LDConfig secondaryMobileKeys: May not contain an empty mobile key." userInfo:nil];
        @throw invalidConfigException;
    }
    _secondaryMobileKeys = secondaryMobileKeys;
}

- (void)setBaseUrl:(NSString *)baseUrl {
    if (baseUrl) {
        DEBUG_LOG(@"Set LDConfig baseUrl: %@", baseUrl);
        _baseUrl = [baseUrl copy];
    } else {
        DEBUG_LOG(@"Set LDConfig default baseUrl: %@", kBaseUrl);
        _baseUrl = kBaseUrl;
    }
}

- (void)setEventsUrl:(NSString *)eventsUrl {
    if (eventsUrl) {
        DEBUG_LOG(@"Set LDConfig eventsUrl: %@", eventsUrl);
        _eventsUrl = [eventsUrl copy];
    } else {
        DEBUG_LOG(@"Set LDConfig default eventsUrl: %@", kEventsUrl);
        _eventsUrl = kEventsUrl;
    }
}

- (void)setCapacity:(NSNumber *)capacity {
    if (capacity != nil) {
        DEBUG_LOG(@"Set LDConfig capacity: %@", capacity);
        _capacity = capacity;
    } else {
        DEBUG_LOG(@"Set LDConfig default capacity: %d", kCapacity);
        _capacity = [NSNumber numberWithInt:kCapacity];
    }
}

- (void)setConnectionTimeout:(NSNumber *)connectionTimeout {
    if (connectionTimeout != nil) {
        DEBUG_LOG(@"Set LDConfig timeout: %@", connectionTimeout);
        _connectionTimeout = connectionTimeout;
    } else {
        DEBUG_LOG(@"Set LDConfig default timeout: %d", kConnectionTimeout);
        _connectionTimeout = [NSNumber numberWithInt:kConnectionTimeout];
    }
}

- (void)setFlushInterval:(NSNumber *)flushInterval {
    if (flushInterval != nil) {
        DEBUG_LOG(@"Set LDConfig flush interval: %@", flushInterval);
        _flushInterval = flushInterval;
    } else {
        DEBUG_LOG(@"Set LDConfig default flush interval: %d", kDefaultFlushInterval);
        _flushInterval = [NSNumber numberWithInt:kDefaultFlushInterval];
    }
}

- (void)setPollingInterval:(NSNumber *)pollingInterval {
    if (pollingInterval != nil) {
        DEBUG_LOG(@"Set LDConfig polling interval: %@", pollingInterval);
        _pollingInterval = [NSNumber numberWithInt:MAX(pollingInterval.intValue, kMinimumPollingInterval)];
    } else {
        DEBUG_LOG(@"Set LDConfig default polling interval: %d", kDefaultPollingInterval);
        _pollingInterval = [NSNumber numberWithInt:kDefaultPollingInterval];
    }
}

- (void)setBackgroundFetchInterval:(NSNumber *)backgroundFetchInterval {
    if (backgroundFetchInterval != nil) {
        DEBUG_LOG(@"Set LDConfig background fetch interval: %@", backgroundFetchInterval);
        _backgroundFetchInterval = backgroundFetchInterval;
    } else {
        DEBUG_LOG(@"Set LDConfig default background fetch interval: %d", kDefaultPollingInterval);
        _backgroundFetchInterval = [NSNumber numberWithInt:kDefaultBackgroundFetchInterval];
    }
}

- (void)setStreaming:(BOOL)streaming {
    _streaming = streaming;
    DEBUG_LOG(@"Set LDConfig streaming enabled: %d", streaming);
}

- (void)setPrivateUserAttributes:(NSArray<NSString *>*)privateAttributes {
    _privateUserAttributes = privateAttributes;
    DEBUG_LOG(@"Set LDConfig privateAttributes set: %@", privateAttributes.description);
}

- (void)setDebugEnabled:(BOOL)debugEnabled {
    _debugEnabled = debugEnabled;
    DEBUG_LOG(@"Set LDConfig debug enabled: %d", debugEnabled);
}

- (void)setInlineUserInEvents:(BOOL)inlineUserInEvents {
    _inlineUserInEvents = inlineUserInEvents;
    DEBUG_LOG(@"Set LDConfig inlineUserInEvents: %d", inlineUserInEvents);
}

- (BOOL)isFlagRetryStatusCode:(NSInteger)statusCode {
    return [self.flagRetryStatusCodes containsObject:@(statusCode)];
}

-(NSString*)description {
    NSString *description = [NSString stringWithFormat:@"<LDConfig:%p mobileKey:%@", self, self.mobileKey];
    description = [NSString stringWithFormat:@"%@ secondaryKeys:%@", description, [self secondaryMobileKeysDescription]];
    description = [NSString stringWithFormat:@"%@ baseUrl:%@", description, self.baseUrl];
    description = [NSString stringWithFormat:@"%@ streamUrl:%@", description, self.streamUrl];
    description = [NSString stringWithFormat:@"%@ eventsUrl:%@", description, self.eventsUrl];
    description = [NSString stringWithFormat:@"%@ capacity:%ld connectionTimeout:%ld", description, (long)[self.capacity integerValue], (long)[self.connectionTimeout integerValue]];
    description = [NSString stringWithFormat:@"%@ capacity:%ld connectionTimeout:%ld", description, (long)[self.capacity integerValue], (long)[self.connectionTimeout integerValue]];
    description = [NSString stringWithFormat:@"%@ flushInterval:%ld pollingInterval:%ld backgroundFetchInterval:%ld", description,
                   (long)[self.flushInterval integerValue], (long)[self.pollingInterval integerValue], (long)[self.backgroundFetchInterval integerValue]];
    description = [NSString stringWithFormat:@"%@ capacity:%ld connectionTimeout:%ld", description, (long)[self.capacity integerValue], (long)[self.connectionTimeout integerValue]];
    description = [NSString stringWithFormat:@"%@ streaming:%@", description, [NSString stringWithBool:self.streaming]];
    description = [NSString stringWithFormat:@"%@ privateUserAttributes:%@", description, [self.privateUserAttributes componentsJoinedByString:@","]];
    description = [NSString stringWithFormat:@"%@ allUserAttributesPrivate:%@", description, [NSString stringWithBool:self.allUserAttributesPrivate]];
    description = [NSString stringWithFormat:@"%@ useReport:%@", description, [NSString stringWithBool:self.useReport]];
    description = [NSString stringWithFormat:@"%@ useReport:%@", description, [NSString stringWithBool:self.useReport]];
    description = [NSString stringWithFormat:@"%@ inlineUserInEvents:%@", description, [NSString stringWithBool:self.inlineUserInEvents]];
    description = [NSString stringWithFormat:@"%@ debugEnabled:%@", description, [NSString stringWithBool:self.debugEnabled]];
    description = [NSString stringWithFormat:@"%@>", description];
    return description;
}

-(NSString*)secondaryMobileKeysDescription {
    if (self.secondaryMobileKeys.count == 0) {
        return @"{}";
    }
    NSString *secondaryKeysDescription = @"{";
    NSString *separator = @"";
    for (NSString *environmentName in self.secondaryMobileKeys.allKeys) {
        secondaryKeysDescription = [NSString stringWithFormat:@"%@%@%@:%@", secondaryKeysDescription, separator, environmentName, self.secondaryMobileKeys[environmentName]];
        separator = @",";
    }
    secondaryKeysDescription = [NSString stringWithFormat:@"%@}", secondaryKeysDescription];
    return secondaryKeysDescription;
}
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation LDConfigBuilder
#pragma clang diagnostic pop

- (id)init {
    self = [super init];
    self.config = [[LDConfig alloc] initWithMobileKey:@""];
    return self;
}

-(LDConfigBuilder *)withMobileKey:(NSString *)mobileKey {
    _config.mobileKey = mobileKey;
    return self;
}

-(LDConfigBuilder *)withBaseUrl:(NSString *)baseUrl {
    _config.baseUrl = baseUrl;
    return self;
}

-(LDConfigBuilder *)withEventsUrl:(NSString *)eventsUrl {
    _config.eventsUrl = eventsUrl;
    return self;
}

-(LDConfigBuilder *)withCapacity:(int)capacity {
    _config.capacity = [NSNumber numberWithInt:capacity];
    return self;
}

-(LDConfigBuilder *)withConnectionTimeout:(int)connectionTimeout {
    _config.connectionTimeout = [NSNumber numberWithInt:connectionTimeout];;
    return self;
}

- (LDConfigBuilder *)withFlushInterval:(int)flushInterval {
    _config.flushInterval = [NSNumber numberWithInt:flushInterval];
    return self;
}

- (LDConfigBuilder *)withPollingInterval:(int)pollingInterval {
    _config.pollingInterval = [NSNumber numberWithInt:pollingInterval];
    return self;
}

- (LDConfigBuilder *)withBackgroundFetchInterval:(int)inputBackgroundFetchInterval {
    _config.backgroundFetchInterval = [NSNumber numberWithInt:MAX(inputBackgroundFetchInterval, kMinimumBackgroundFetchInterval)];
    return self;
}

- (LDConfigBuilder *)withDebugEnabled:(BOOL)debugEnabled {
    _config.debugEnabled = debugEnabled;
    return self;
}

-(LDConfigBuilder *)withStreaming:(BOOL)streamingEnabled {
    _config.streaming = streamingEnabled;
    return self;
}

-(LDConfig *)build {
    return _config;
}

@end



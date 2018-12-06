//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDClient.h"
#import "LDUserModel.h"
#import "LDEnvironment.h"
#import "LDUtil.h"
#import "LDPollingManager.h"
#import "DarklyConstants.h"
#import "NSThread+MainExecutable.h"
#import "LDThrottler.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigTracker.h"
#import "NSURLSession+LaunchDarkly.h"

@interface LDClient()
@property (nonatomic, assign) BOOL isOnline;
@property (nonatomic, strong) LDUserModel *ldUser;
@property (nonatomic, strong) LDConfig *ldConfig;
@property (nonatomic, assign) BOOL clientStarted;
@property (nonatomic, strong) LDThrottler *throttler;
@property (nonatomic, assign) BOOL willGoOnlineAfterDelay;
@property (nonatomic, strong) LDEnvironment *primaryEnvironment;
@property (nonatomic, strong) NSMutableDictionary<NSString*, LDEnvironment*> *secondaryEnvironments;    // <mobile-key: LDEnvironment>
@end

@implementation LDClient

+(LDClient *)sharedInstance
{
    static LDClient *sharedLDClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLDClient = [[self alloc] init];
        sharedLDClient.throttler = [[LDThrottler alloc] initWithMaxDelayInterval:kMaxThrottlingDelayInterval];
    });
    return sharedLDClient;
}

-(NSString*)environmentName {
    return kLDPrimaryEnvironmentName;
}

-(void)setDelegate:(id<ClientDelegate>)delegate {
    _delegate = delegate;
    self.primaryEnvironment.delegate = delegate;
}

-(void)dealloc {
    self.delegate = nil;
}

#pragma mark - SDK Control

-(BOOL)start:(LDConfigBuilder *)inputConfigBuilder userBuilder:(LDUserBuilder *)inputUserBuilder {
    return [self start:[inputConfigBuilder build] withUserBuilder:inputUserBuilder];
}

- (BOOL)start:(LDConfig *)inputConfig withUserBuilder:(LDUserBuilder *)inputUserBuilder {
    DEBUG_LOGX(@"LDClient start method called");
    if (self.clientStarted) {
        DEBUG_LOGX(@"LDClient client already started");
        return NO;
    }
    if (!inputConfig) {
        DEBUG_LOGX(@"LDClient client requires a config to start");
        return NO;
    }
    self.ldConfig = inputConfig;
    [LDUtil setLogLevel:[self.ldConfig debugEnabled] ? DarklyLogLevelDebug : DarklyLogLevelCriticalOnly];
    [NSURLSession setSharedLDSessionForConfig:self.ldConfig];

    self.clientStarted = YES;
    DEBUG_LOGX(@"LDClient started");
    inputUserBuilder = inputUserBuilder ?: [[LDUserBuilder alloc] init];
    self.ldUser = [inputUserBuilder build];

    self.primaryEnvironment = [LDEnvironment environmentForMobileKey:self.ldConfig.mobileKey config:self.ldConfig user:self.ldUser];
    self.primaryEnvironment.delegate = self.delegate;
    [self.primaryEnvironment start];
    if (self.ldConfig.secondaryMobileKeys.count > 0) {
        self.secondaryEnvironments = [NSMutableDictionary dictionaryWithCapacity:self.ldConfig.secondaryMobileKeys.count];
    }
    for (NSString *secondaryKey in self.ldConfig.secondaryMobileKeys.allValues) {
        LDEnvironment *secondaryEnvironment = [LDEnvironment environmentForMobileKey:secondaryKey config:self.ldConfig user:self.ldUser];
        [secondaryEnvironment start];
        self.secondaryEnvironments[secondaryKey] = secondaryEnvironment;
    }
    [self setOnline:YES];
    
    return YES;
}

-(void)setOnline:(BOOL)goOnline {
    [self setOnline:goOnline completion:nil];
}

-(void)setOnline:(BOOL)goOnline completion:(void(^)(void))completion {
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        if (completion) {
            completion();
        }
        return;
    }
    self.willGoOnlineAfterDelay = goOnline;
    if (goOnline == self.isOnline && [self environmentsMatchOnline:goOnline]) {
        DEBUG_LOG(@"LDClient setOnline:%@ aborted. LDClient is already %@", goOnline ? @"YES" : @"NO", goOnline ? @"online" : @"offline");
        if (completion) {
            completion();
        }
        return;
    }

    if (!goOnline) {
        DEBUG_LOGX(@"LDClient setOnline:NO called");
        [self _setOnline:NO completion:completion];
        return;
    }
    [self.throttler runThrottled:^{
        if (!self.willGoOnlineAfterDelay) {
            DEBUG_LOGX(@"LDClient setOnline:YES aborted. Client last received an offline request when the throttling timer expired.");
            if (completion) {
                completion();
            }
            return;
        }
        DEBUG_LOGX(@"LDClient setOnline:YES called");
        [self _setOnline:YES completion:completion];
    }];
}

-(BOOL)environmentsMatchOnline:(BOOL)online {
    if (self.primaryEnvironment.isOnline != online) {
        return NO;
    }
    for (LDEnvironment *environment in self.secondaryEnvironments.allValues) {
        if (environment.isOnline != online) {
            return NO;
        }
    }
    return YES;
}

-(void)_setOnline:(BOOL)isOnline completion:(void(^)(void))completion {
    self.isOnline = isOnline;
    self.primaryEnvironment.online = isOnline;
    for (LDEnvironment *secondaryEnvironment in self.secondaryEnvironments.allValues) {
        secondaryEnvironment.online = isOnline;
    }
    if (completion) {
        completion();
    }
}

- (BOOL)flush {
    DEBUG_LOGX(@"LDClient flush method called");
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
    BOOL result = [self.primaryEnvironment flush];
    for (LDEnvironment *secondaryEnvironment in self.secondaryEnvironments.allValues) {
        result = result && [secondaryEnvironment flush];
    }

    return result;
}

- (BOOL)stopClient {
    DEBUG_LOGX(@"LDClient stop method called");
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }

    [self setOnline:NO];
    [self.primaryEnvironment stop];
    self.primaryEnvironment = nil;
    for (LDEnvironment *secondaryEnvironment in self.secondaryEnvironments.allValues) {
        [secondaryEnvironment stop];
    }
    self.clientStarted = NO;
    [self.secondaryEnvironments removeAllObjects];
    return YES;
}

#pragma mark - Variation

- (BOOL)boolVariation:(NSString *)flagKey fallback:(BOOL)fallback{
    if (!self.clientStarted) {
        DEBUG_LOG(@"LDClient %@ flagKey:%@ fallback:%@ aborted. Client not started.", NSStringFromSelector(_cmd), flagKey, @(fallback));
        return fallback;
    }

    DEBUG_LOG(@"LDClient %@ called flagKey:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, @(fallback));
    return [self.primaryEnvironment boolVariation:flagKey fallback:fallback];
}

- (NSNumber*)numberVariation:(NSString *)flagKey fallback:(NSNumber*)fallback{
    if (!self.clientStarted) {
        DEBUG_LOG(@"LDClient %@ flagKey:%@ fallback:%@ aborted. Client not started.", NSStringFromSelector(_cmd), flagKey, fallback);
        return fallback;
    }

    DEBUG_LOG(@"LDClient %@ called flagKey:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, fallback);
    return [self.primaryEnvironment numberVariation:flagKey fallback:fallback];
}

- (double)doubleVariation:(NSString *)flagKey fallback:(double)fallback {
    if (!self.clientStarted) {
        DEBUG_LOG(@"LDClient %@ flagKey:%@ fallback:%@ aborted. Client not started.", NSStringFromSelector(_cmd), flagKey, @(fallback));
        return fallback;
    }

    DEBUG_LOG(@"LDClient %@ called flagKey:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, @(fallback));
    return [self.primaryEnvironment doubleVariation:flagKey fallback:fallback];
}

- (NSString*)stringVariation:(NSString *)flagKey fallback:(NSString*)fallback{
    if (!self.clientStarted) {
        DEBUG_LOG(@"LDClient %@ flagKey:%@ fallback:%@ aborted. Client not started.", NSStringFromSelector(_cmd), flagKey, fallback);
        return fallback;
    }

    DEBUG_LOG(@"LDClient %@ called flagKey:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, fallback);
    return [self.primaryEnvironment stringVariation:flagKey fallback:fallback];
}

- (NSArray*)arrayVariation:(NSString *)flagKey fallback:(NSArray*)fallback{
    if (!self.clientStarted) {
        DEBUG_LOG(@"LDClient %@ flagKey:%@ fallback:%@ aborted. Client not started.", NSStringFromSelector(_cmd), flagKey, fallback);
        return fallback;
    }

    DEBUG_LOG(@"LDClient %@ called flagKey:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, fallback);
    return [self.primaryEnvironment arrayVariation:flagKey fallback:fallback];
}

- (NSDictionary*)dictionaryVariation:(NSString *)flagKey fallback:(NSDictionary*)fallback{
    if (!self.clientStarted) {
        DEBUG_LOG(@"LDClient %@ flagKey:%@ fallback:%@ aborted. Client not started.", NSStringFromSelector(_cmd), flagKey, fallback);
        return fallback;
    }

    DEBUG_LOG(@"LDClient %@ called flagKey:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, fallback);
    return [self.primaryEnvironment dictionaryVariation:flagKey fallback:fallback];
}

-(NSDictionary*)allFlags {
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return nil;
    }
    return self.primaryEnvironment.allFlags;
}

#pragma mark - Event Tracking

-(BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary {
    DEBUG_LOG(@"LDClient track method called for event=%@ and data=%@", eventName, dataDictionary);
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }

    return [self.primaryEnvironment track:eventName data:dataDictionary];
}

#pragma mark - User

- (BOOL)updateUser:(LDUserBuilder *)builder {
    DEBUG_LOGX(@"LDClient updateUser method called");
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient aborted updateUser: client not started");
        return NO;
    }
    if (!builder) {
        DEBUG_LOGX(@"LDClient aborted updateUser: LDUserBuilder is nil");
        return NO;
    }

    self.ldUser = [builder build];
    [self.primaryEnvironment updateUser:self.ldUser];
    for (LDEnvironment *secondaryEnvironment in self.secondaryEnvironments.allValues) {
        [secondaryEnvironment updateUser:self.ldUser];
    }

    return YES;
}

- (LDUserBuilder *)currentUserBuilder {
    DEBUG_LOGX(@"LDClient currentUserBuilder method called");
    if (self.clientStarted) {
        return [LDUserBuilder currentBuilder:self.ldUser];
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return nil;
    }
}

#pragma mark - Multiple Environments

+(id<LDClientInterface>)environmentForMobileKeyNamed:(NSString*)name {
    if (![LDClient sharedInstance].clientStarted) {
        return nil;
    }
    if (![name isEqualToString:kLDPrimaryEnvironmentName] && ![[LDClient sharedInstance].ldConfig.secondaryMobileKeys.allKeys containsObject:name]) {
        NSException *missingKeyNameException =
        [NSException exceptionWithName:NSInvalidArgumentException reason:@"Environment key name does not appear in LDConfig.secondaryMobileKeys." userInfo:nil];
        @throw missingKeyNameException;

    }
    if ([name isEqualToString:kLDPrimaryEnvironmentName]) {
        return [LDClient sharedInstance].primaryEnvironment;
    }
    return [LDClient sharedInstance].secondaryEnvironments[[LDClient sharedInstance].ldConfig.secondaryMobileKeys[name]];
}
@end

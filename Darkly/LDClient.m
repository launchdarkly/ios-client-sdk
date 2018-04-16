//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDClient.h"
#import "LDClientManager.h"
#import "LDUtil.h"
#import "LDDataManager.h"
#import "LDPollingManager.h"
#import "DarklyConstants.h"
#import "NSThread+MainExecutable.h"
#import "LDThrottler.h"

@interface LDClient()
@property (nonatomic, assign) BOOL isOnline;
@property(nonatomic, strong) LDUserModel *ldUser;
@property(nonatomic, strong) LDConfig *ldConfig;
@property (nonatomic, assign) BOOL clientStarted;
@property (nonatomic, strong) LDThrottler *throttler;
@property (nonatomic, assign) BOOL willGoOnlineAfterDelay;
@end

@implementation LDClient

+(LDClient *)sharedInstance
{
    static LDClient *sharedLDClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLDClient = [[self alloc] init];
        sharedLDClient.throttler = [[LDThrottler alloc] initWithMaxDelayInterval:kMaxThrottlingDelayInterval];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(userUpdated)
                                                     name: kLDUserUpdatedNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(userUnchanged)
                                                     name: kLDUserNoChangeNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(serverUnavailable)
                                                     name:kLDServerConnectionUnavailableNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(configFlagUpdated:)
                                                     name:kLDFlagConfigChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(handleClientUnauthorizedNotification)
                                                     name:kLDClientUnauthorizedNotification object:nil];
    });
    return sharedLDClient;
}

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
    
    self.clientStarted = YES;
    DEBUG_LOGX(@"LDClient started");
    inputUserBuilder = inputUserBuilder ?: [[LDUserBuilder alloc] init];
    self.ldUser = [inputUserBuilder build];
    
    [self setOnline:YES];
    
    return YES;
}

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

    self.ldUser = [LDUserBuilder compareNewBuilder:builder withUser:self.ldUser];
    [[LDClientManager sharedInstance] updateUser];
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

- (BOOL)boolVariation:(NSString *)featureKey fallback:(BOOL)fallback{
    DEBUG_LOG(@"LDClient boolVariation method called for feature=%@ and fallback=%d", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (self.clientStarted) {
        BOOL flagExists = [self.ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [self.ldUser flagValue: featureKey];
        BOOL returnValue = fallback;
        if ([flagValue isKindOfClass:[NSNumber class]] && flagExists) {
            returnValue = [(NSNumber *)flagValue boolValue];
        }
        
        [[LDDataManager sharedManager] createFeatureEventWithFlagKey: featureKey flagValue:[NSNumber numberWithBool:returnValue] defaultFlagValue:[NSNumber numberWithBool:fallback] user:self.ldUser config:self.ldConfig];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return fallback;
}

- (NSNumber*)numberVariation:(NSString *)featureKey fallback:(NSNumber*)fallback{
    DEBUG_LOG(@"LDClient numberVariation method called for feature=%@ and fallback=%@", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (self.clientStarted) {
        BOOL flagExists = [self.ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [self.ldUser flagValue: featureKey];
        NSNumber *returnValue = fallback;
        if ([flagValue isKindOfClass:[NSNumber class]] && flagExists) {
            returnValue = (NSNumber *)flagValue;
        }
        
        [[LDDataManager sharedManager] createFeatureEventWithFlagKey: featureKey flagValue:returnValue defaultFlagValue:fallback user:self.ldUser config:self.ldConfig];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return fallback;
}

- (double)doubleVariation:(NSString *)featureKey fallback:(double)fallback {
    DEBUG_LOG(@"LDClient doubleVariation method called for feature=%@ and fallback=%f", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return fallback;
    }
    BOOL flagExists = [self.ldUser doesFlagExist: featureKey];
    id flagValue = [self.ldUser flagValue: featureKey];
    double returnValue = fallback;
    if (flagExists && [flagValue isKindOfClass:[NSNumber class]]) {
        returnValue = [((NSNumber *)flagValue) doubleValue];
    }
    
    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:featureKey flagValue:[NSNumber numberWithDouble:returnValue] defaultFlagValue:[NSNumber numberWithDouble:fallback] user:self.ldUser config:self.ldConfig];
    return returnValue;
}

- (NSString*)stringVariation:(NSString *)featureKey fallback:(NSString*)fallback{
    DEBUG_LOG(@"LDClient stringVariation method called for feature=%@ and fallback=%@", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (self.clientStarted) {
        BOOL flagExists = [self.ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [self.ldUser flagValue: featureKey];
        NSString *returnValue = fallback;
        if ([flagValue isKindOfClass:[NSString class]] && flagExists) {
            returnValue = (NSString *)flagValue;
        }
        
        [[LDDataManager sharedManager] createFeatureEventWithFlagKey: featureKey flagValue:returnValue defaultFlagValue:fallback user:self.ldUser config:self.ldConfig];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return fallback;
}

- (NSArray*)arrayVariation:(NSString *)featureKey fallback:(NSArray*)fallback{
    DEBUG_LOG(@"LDClient arrayVariation method called for feature=%@ and fallback=%@", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return fallback;
    }
    BOOL flagExists = [self.ldUser doesFlagExist: featureKey];
    id flagValue = [self.ldUser flagValue: featureKey];
    NSArray *returnValue = fallback;
    if (flagExists && [flagValue isKindOfClass:[NSArray class]]) {
        returnValue = (NSArray *)flagValue;
    }
    
    [[LDDataManager sharedManager] createFeatureEventWithFlagKey: featureKey flagValue:returnValue defaultFlagValue:fallback user:self.ldUser config:self.ldConfig];
    return returnValue;
}

- (NSDictionary*)dictionaryVariation:(NSString *)featureKey fallback:(NSDictionary*)fallback{
    DEBUG_LOG(@"LDClient dictionaryVariation method called for feature=%@ and fallback=%@", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return fallback;
    }
    BOOL flagExists = [self.ldUser doesFlagExist: featureKey];
    id flagValue = [self.ldUser flagValue: featureKey];
    NSDictionary *returnValue = fallback;
    if (flagExists && [flagValue isKindOfClass:[NSDictionary class]]) {
        returnValue = (NSDictionary *)flagValue;
    }
    
    [[LDDataManager sharedManager] createFeatureEventWithFlagKey: featureKey flagValue:returnValue defaultFlagValue:fallback user:self.ldUser config:self.ldConfig];
    return returnValue;
}

- (BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary
{
    DEBUG_LOG(@"LDClient track method called for event=%@ and data=%@", eventName, dataDictionary);
    if (self.clientStarted) {
        [[LDDataManager sharedManager] createCustomEventWithKey:eventName customData: dataDictionary user:self.ldUser config:self.ldConfig];
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
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
    if (goOnline == self.isOnline) {
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

-(void)_setOnline:(BOOL)isOnline completion:(void(^)(void))completion {
    self.isOnline = isOnline;
    [[LDClientManager sharedInstance] setOnline:isOnline];
    if (completion) {
        completion();
    }
}

- (BOOL)flush {
    DEBUG_LOGX(@"LDClient flush method called");
    if (self.clientStarted) {
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager flushEvents];
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

- (BOOL)stopClient {
    DEBUG_LOGX(@"LDClient stop method called");
    if (!self.clientStarted) {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }

    [self setOnline:NO];
    self.clientStarted = NO;
    return YES;
}

// Notification handler for ClientManager user updated
-(void)userUpdated {
    if (![self.delegate respondsToSelector:@selector(userDidUpdate)]) { return; }
    [NSThread performOnMainThread:^{
        [self.delegate userDidUpdate];
    }];
}

// Notification handler for ClientManager user unchanged
-(void)userUnchanged {
    if (![self.delegate respondsToSelector:@selector(userUnchanged)]) { return; }
    [NSThread performOnMainThread:^{
        [self.delegate userUnchanged];
    }];
}

// Notification handler for ClientManager server connection failed
-(void)serverUnavailable {
    if (![self.delegate respondsToSelector:@selector(serverConnectionUnavailable)]) { return; }
    [NSThread performOnMainThread:^{
        [self.delegate serverConnectionUnavailable];
    }];
}

// Notification handler for DataManager config flag update
-(void)configFlagUpdated:(NSNotification *)notification {
    if (![self.delegate respondsToSelector:@selector(featureFlagDidUpdate:)]) { return; }
    [NSThread performOnMainThread:^{
        [self.delegate featureFlagDidUpdate:[notification.userInfo objectForKey:@"flagkey"]];
    }];
}

//Notification handler for Client Unauthorized notification
-(void)handleClientUnauthorizedNotification {
    [NSThread performOnMainThread:^{
        DEBUG_LOGX(@"LDClient received Client Unauthorized notification. Taking LDClient offline.");
        [self setOnline:NO];
    }];
}

-(void)dealloc {
    self.delegate = nil;
}
@end

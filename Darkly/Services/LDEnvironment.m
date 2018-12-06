//
//  LDEnvironment.m
//  Darkly
//
//  Created by Mark Pokorny on 10/3/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEnvironment.h"
#import "LDEnvironmentController.h"
#import "LDDataManager.h"

#import "DarklyConstants.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigValue.h"

#import "LDUtil.h"
#import "NSThread+MainExecutable.h"

@interface LDEnvironment ()

@property (nonatomic, copy) NSString *mobileKey;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, assign, getter=isStarted) BOOL start;

@property (nonatomic, strong) LDEnvironmentController *environmentController;
@property (nonatomic, strong) LDDataManager *dataManager;

@end

@implementation LDEnvironment
#pragma mark Lifecycle
+(instancetype)environmentForMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user {
    return [[LDEnvironment alloc] initForMobileKey:mobileKey config:config user:user];
}

-(instancetype)initForMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user {
    if (!(self = [super init])) {
        return nil;
    }

    self.mobileKey = mobileKey;
    self.config = config;
    self.user = [user copy];
    self.dataManager = [LDDataManager dataManagerWithMobileKey:self.mobileKey config:self.config];
    self.environmentController = [LDEnvironmentController controllerWithMobileKey:self.mobileKey config:self.config user:self.user dataManager:self.dataManager];

    [self registerForNotifications];
    
    return self;
}

-(void)registerForNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserUpdated:) name:kLDUserUpdatedNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserUnchanged:) name:kLDUserNoChangeNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleFeatureFlagsChanged:) name:kLDFeatureFlagsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleServerUnavailable:) name:kLDServerConnectionUnavailableNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleClientUnauthorized:) name:kLDClientUnauthorizedNotification object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.delegate = nil;
}

-(BOOL)isPrimary {
    return [self.mobileKey isEqualToString:self.config.mobileKey];
}

-(NSString*)environmentName {
    if ([self.mobileKey isEqualToString:self.config.mobileKey]) {
        return kLDPrimaryEnvironmentName;
    }
    NSMutableDictionary *swappedMobileKeys = [NSMutableDictionary dictionaryWithCapacity:self.config.secondaryMobileKeys.count];
    [self.config.secondaryMobileKeys enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        swappedMobileKeys[obj] = key;
    }];
    return swappedMobileKeys[self.mobileKey];
}

#pragma mark - Controls

-(void)start {
    DEBUG_LOGX(@"LDEnvironment starting.");
    if (self.isPrimary) {
        [LDDataManager convertToEnvironmentBasedCacheForUser:self.user config:self.config];
    }
    self.start = YES;
    self.user.flagConfig = [self.dataManager retrieveFlagConfigForUser:self.user];
    [self.dataManager saveUser:self.user];
    [self.dataManager recordIdentifyEventWithUser:self.user];
}

-(void)setOnline:(BOOL)goOnline {
    if (!self.isStarted && goOnline) {  //Allow set offline when not started
        DEBUG_LOG(@"LDEnvironment setOnline:%@ aborted. The environment is not started.", goOnline ? @"YES" : @"NO");
        return;
    }
    if (goOnline == self.isOnline && goOnline == self.environmentController.isOnline) {
        DEBUG_LOG(@"LDEnvironment setOnline:%@ aborted. The environment is already %@.", goOnline ? @"YES" : @"NO", goOnline ? @"online" : @"offline");
        return;
    }

    DEBUG_LOG(@"LDEnvironment going %@.", goOnline ? @"online" : @"offline");
    _online = goOnline;
    self.environmentController.online = goOnline;
}

-(BOOL)flush {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return NO;
    }
    if (!self.isOnline) {
        DEBUG_LOG(@"LDEnvironment %@ called for mobile key %@ not online", NSStringFromSelector(_cmd), self.mobileKey);
        return NO;
    }
    DEBUG_LOG(@"LDEnvironment %@ called.", NSStringFromSelector(_cmd));
    [self.environmentController flushEvents];
    return YES;
}

-(void)stop {
    DEBUG_LOGX(@"LDEnvironment stopping.");
    self.online = NO;
    self.start = NO;
}

#pragma mark - Feature Flags

-(BOOL)boolVariation:(NSString *)flagKey fallback:(BOOL)fallback {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return fallback;
    }
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
    BOOL returnValue = flagConfigValue.value && [flagConfigValue.value isKindOfClass:[NSNumber class]] ? [flagConfigValue.value boolValue] : fallback;

    DEBUG_LOG(@"LDEnvironment %@ flagKey:%@ reportedValue:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, @(returnValue), @(fallback));
    [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                          reportedFlagValue:@(returnValue)
                                            flagConfigValue:flagConfigValue
                                           defaultFlagValue:@(fallback)
                                                       user:self.user];
    return returnValue;
}

-(NSNumber*)numberVariation:(NSString *)flagKey fallback:(NSNumber*)fallback {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return fallback;
    }
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
    NSNumber *returnValue = flagConfigValue.value && [flagConfigValue.value isKindOfClass:[NSNumber class]] ? flagConfigValue.value : fallback;

    DEBUG_LOG(@"LDEnvironment %@ flagKey:%@ reportedValue:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, returnValue, fallback);
    [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                          reportedFlagValue:returnValue
                                            flagConfigValue:flagConfigValue
                                           defaultFlagValue:fallback
                                                       user:self.user];
    return returnValue;
}

-(double)doubleVariation:(NSString *)flagKey fallback:(double)fallback {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return fallback;
    }
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
    double returnValue = flagConfigValue.value && [flagConfigValue.value isKindOfClass:[NSNumber class]] ? [flagConfigValue.value doubleValue] : fallback;

    DEBUG_LOG(@"LDEnvironment %@ flagKey:%@ reportedValue:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, @(returnValue), @(fallback));
    [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                          reportedFlagValue:@(returnValue)
                                            flagConfigValue:flagConfigValue
                                           defaultFlagValue:@(fallback)
                                                       user:self.user];
    return returnValue;
}

-(NSString*)stringVariation:(NSString *)flagKey fallback:(NSString*)fallback {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return fallback;
    }
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
    NSString *returnValue = flagConfigValue.value && [flagConfigValue.value isKindOfClass:[NSString class]] ? flagConfigValue.value : fallback;

    DEBUG_LOG(@"LDEnvironment %@ flagKey:%@ reportedValue:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, returnValue, fallback);
    [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                          reportedFlagValue:returnValue
                                            flagConfigValue:flagConfigValue
                                           defaultFlagValue:fallback
                                                       user:self.user];
    return returnValue;
}

-(NSArray*)arrayVariation:(NSString *)flagKey fallback:(NSArray*)fallback {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return fallback;
    }
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
    NSArray *returnValue = flagConfigValue.value && [flagConfigValue.value isKindOfClass:[NSArray class]] ? flagConfigValue.value : fallback;

    DEBUG_LOG(@"LDEnvironment %@ flagKey:%@ reportedValue:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, returnValue, fallback);
    [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                          reportedFlagValue:returnValue
                                            flagConfigValue:flagConfigValue
                                           defaultFlagValue:fallback
                                                       user:self.user];
    return returnValue;
}

-(NSDictionary*)dictionaryVariation:(NSString *)flagKey fallback:(NSDictionary*)fallback {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return fallback;
    }
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
    NSDictionary *returnValue = flagConfigValue.value && [flagConfigValue.value isKindOfClass:[NSDictionary class]] ? flagConfigValue.value : fallback;

    DEBUG_LOG(@"LDEnvironment %@ flagKey:%@ reportedValue:%@ fallback:%@", NSStringFromSelector(_cmd), flagKey, returnValue, fallback);
    [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                          reportedFlagValue:returnValue
                                            flagConfigValue:flagConfigValue
                                           defaultFlagValue:fallback
                                                       user:self.user];
    return returnValue;
}

-(NSDictionary<NSString*, id>*)allFlags {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return nil;
    }
    return [self.user.flagConfig allFlagValues];
}

#pragma mark - Event Tracking

-(BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary {
    if (!self.isStarted) {
        DEBUG_LOG(@"LDEnvironment %@ called while environment is not started.", NSStringFromSelector(_cmd));
        return NO;
    }
    DEBUG_LOG(@"LDEnvironment %@ eventName:%@ data:%@.", NSStringFromSelector(_cmd), eventName, dataDictionary);
    [self.dataManager recordCustomEventWithKey:eventName customData:dataDictionary user:self.user];
    return YES;
}

#pragma mark - User

-(void)updateUser:(LDUserModel*)newUser {
    if (!self.isStarted) {
        DEBUG_LOGX(@"LDEnvironment updateUser aborted. The environment is not started.");
        return;
    }
    if (newUser == nil) {
        DEBUG_LOGX(@"LDEnvironment updateUser aborted. The newUser is nil.");
        return;
    }

    [self.dataManager recordSummaryEventWithTracker:self.user.flagConfigTracker];

    DEBUG_LOG(@"LDEnvironment updating user key: %@, was online: %@", newUser.key, self.isOnline ? @"YES" : @"NO");
    BOOL wasOnline = self.isOnline;
    self.online = NO;

    self.user = [newUser copy];
    if (self.isPrimary) {
        [LDDataManager convertToEnvironmentBasedCacheForUser:self.user config:self.config];
    }
    self.user.flagConfig = [self.dataManager retrieveFlagConfigForUser:self.user];
    [self.dataManager saveUser:self.user];
    [self.dataManager recordIdentifyEventWithUser:self.user];
    self.environmentController = [LDEnvironmentController controllerWithMobileKey:self.mobileKey config:self.config user:self.user dataManager:self.dataManager];

    self.online = wasOnline;
}

#pragma mark - Notification Handling
-(void)handleUserUpdated:(NSNotification*)notification {
    if (![notification.userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:self.mobileKey]) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(userDidUpdate)]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [NSThread performOnMainThread:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.delegate userDidUpdate];
    } waitUntilDone:NO];
}

-(void)handleUserUnchanged:(NSNotification*)notification  {
    if (![notification.userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:self.mobileKey]) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(userUnchanged)]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [NSThread performOnMainThread:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.delegate userUnchanged];
    } waitUntilDone:NO];
}

-(void)handleFeatureFlagsChanged:(NSNotification *)notification {
    if (![notification.userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:self.mobileKey]) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(featureFlagDidUpdate:)]) {
        return;
    }
    [self notifyDelegateOfUpdatesForFlagKeys:notification.userInfo[kLDNotificationUserInfoKeyFlagKeys]];
}

-(void)notifyDelegateOfUpdatesForFlagKeys:(NSArray<NSString*>*)updatedFlagKeys {
    if (!self.isStarted || !self.isOnline) {
        return;
    }
    if (updatedFlagKeys == nil || updatedFlagKeys.count == 0) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(featureFlagDidUpdate:)]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [NSThread performOnMainThread:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        for (NSString *flagKey in updatedFlagKeys) {
            [strongSelf.delegate featureFlagDidUpdate:flagKey];
        }
    } waitUntilDone:NO];
}

-(void)handleServerUnavailable:(NSNotification*)notification  {
    if (![notification.userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:self.mobileKey]) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(serverConnectionUnavailable)]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [NSThread performOnMainThread:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.delegate serverConnectionUnavailable];
    } waitUntilDone:NO];
}

-(void)handleClientUnauthorized:(NSNotification*)notification {
    if (![notification.userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:self.mobileKey]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [NSThread performOnMainThread:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        DEBUG_LOG(@"LDEnvironment for mobile key: %@ received Client Unauthorized notification. Taking LDEnvironment offline.", self.mobileKey);
        strongSelf.online = NO;
    } waitUntilDone:NO];
}

@end

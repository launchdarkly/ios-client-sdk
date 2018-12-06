//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDEnvironmentController.h"
#import "LDPollingManager.h"
#import "LDDataManager.h"
#import "LDUtil.h"
#import "LDUserModel.h"
#import "LDEventModel.h"
#import "LDFlagConfigModel.h"
#import "NSDictionary+LaunchDarkly.h"
#import <DarklyEventSource/LDEventSource.h>
#import "LDEvent+Unauthorized.h"
#import "LDEvent+EventTypes.h"

NSString * const kLDStreamPath = @"meval";

@interface LDEnvironmentController()
@property (nonatomic, copy) NSString *mobileKey;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDUserModel *user;

@property(nonatomic, strong) LDEventSource *eventSource;
@property(nonatomic, strong) NSDate *backgroundTime;
@property (nonatomic, weak) LDDataManager *dataManager;
@property(nonatomic, strong) LDRequestManager *requestManager;
@property (nonatomic, strong) dispatch_queue_t requestCallbackQueue;
@end

@implementation LDEnvironmentController

#pragma mark - Lifecycle

+(instancetype)controllerWithMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user dataManager:(LDDataManager*)dataManager {
    return [[LDEnvironmentController alloc] initWithMobileKey:mobileKey config:config user:user dataManager:dataManager];
}

-(instancetype)initWithMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user dataManager:(LDDataManager*)dataManager {
    if (!(self = [super init])) {
        return nil;
    }
    self.mobileKey = mobileKey;
    self.config = config;
    self.user = user;
    self.dataManager = dataManager;
    self.requestCallbackQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.launchdarkly.environmentController.%@", self.mobileKey] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.requestManager = [LDRequestManager requestManagerForMobileKey:self.mobileKey config:self.config delegate:self callbackQueue:self.requestCallbackQueue];
    [self registerForNotifications];

    return self;
}

-(void)registerForNotifications {
#if TARGET_OS_IOS || TARGET_OS_TV
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
#elif TARGET_OS_OSX
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground) name:NSApplicationWillResignActiveNotification object:nil];
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundFetchInitiated) name:kLDBackgroundFetchInitiated object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncWithServerForConfig) name:kLDFlagConfigTimerFiredNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncWithServerForEvents) name:kLDEventTimerFiredNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self]; //Required pre-ios9
}

#pragma mark - Control

- (void)setOnline:(BOOL)online {
    _online = online;
    online ? [self startPolling] : [self stopPolling];
}

- (void)startPolling {
    if (!self.isOnline) {
        DEBUG_LOGX(@"EnvironmentController startPolling aborted - manager is offline");
        return;
    }

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:self.config isOnline:self.isOnline];

    if ([self.config streaming]) {
        [self configureEventSource];
    }
    else{
        [self syncWithServerForConfig];
        [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:self.config isOnline:self.isOnline];
    }
}

- (void)stopPolling {
    DEBUG_LOGX(@"EnvironmentController stopPolling method called");
    [[LDPollingManager sharedInstance] stopEventPolling];
    
    if (self.config.streaming) {
        [self stopEventSource];
    } else {
        [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    }
    
    [self flushEvents];
}

- (void)willEnterBackground {
    DEBUG_LOGX(@"EnvironmentController entering background");
    [[LDPollingManager sharedInstance] suspendEventPolling];
    
    if (self.config.streaming) {
        [self stopEventSource];
    }
    else{
        [[LDPollingManager sharedInstance] suspendFlagConfigPolling];
    }
    
    [self flushEvents];
    
    self.backgroundTime = [NSDate date];
    
}

- (void)willEnterForeground {
    if (!self.isOnline) {
        DEBUG_LOGX(@"EnvironmentController entering foreground offline");
        return;
    }
    DEBUG_LOGX(@"EnvironmentController entering foreground");
    [[LDPollingManager sharedInstance] resumeEventPollingWhenIsOnline:self.isOnline];
    
    if (self.config.streaming) {
        [self configureEventSource];
    } else {
        [[LDPollingManager sharedInstance] resumeFlagConfigPollingWhenIsOnline:self.isOnline];
    }
}

#pragma mark - Streaming

- (void)configureEventSource {
    @synchronized (self) {
        if (!self.isOnline) {
            DEBUG_LOGX(@"EnvironmentController configureEventSource aborted - manager is offline");
            return;
        }

        if (self.eventSource) {
            DEBUG_LOGX(@"EnvironmentController aborting event source creation - event source running");
            return;
        }

        self.eventSource = [self eventSourceForUser:self.user config:self.config httpHeaders:[self httpHeadersForEventSource]];

        __weak typeof(self) weakSelf = self;
        [self.eventSource onMessage:^(LDEvent *event) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handlePingEvent:event];
            [strongSelf handlePutEvent:event];
            [strongSelf handlePatchEvent:event];
            [strongSelf handleDeleteEvent:event];
        }];

        [self.eventSource onError:^(LDEvent *event) {
            [self reportFlagConfigProcessingCompleteWithNotificationName:kLDServerConnectionUnavailableNotification message:@"clientstream reported error"];
            if (![event isUnauthorizedEvent]) { return; }
            [self reportFlagConfigProcessingCompleteWithNotificationName:kLDClientUnauthorizedNotification message:@"clientstream reported client unauthrorized"];
        }];
    }
}

- (LDEventSource*)eventSourceForUser:(LDUserModel*)user config:(LDConfig*)config httpHeaders:(NSDictionary*)httpHeaders {
    LDEventSource *eventSource;
    if (config.useReport) {
        eventSource = [LDEventSource eventSourceWithURL:[self eventSourceUrlForUser:user config:config]
                                            httpHeaders:httpHeaders
                                          connectMethod:kHTTPMethodReport
                                            connectBody:[[[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString] dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
        eventSource = [LDEventSource eventSourceWithURL:[self eventSourceUrlForUser:user config:config] httpHeaders:httpHeaders connectMethod:nil connectBody:nil];
    }
    return eventSource;
}

- (NSURL*)eventSourceUrlForUser:(LDUserModel *)user config:(LDConfig*)config {
    NSString *eventStreamUrl = [config.streamUrl stringByAppendingPathComponent:kLDStreamPath];
    if (!config.useReport) {
        NSString *encodedUser = [LDUtil base64UrlEncodeString:[[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString]];
        eventStreamUrl = [eventStreamUrl stringByAppendingPathComponent:encodedUser];
    }
    return [NSURL URLWithString:eventStreamUrl];
}

- (NSDictionary *)httpHeadersForEventSource {
    return @{ @"Authorization": [kHeaderMobileKey stringByAppendingString:self.mobileKey],  //Careful!! Use the mobileKey set into this environmentController, not from LDConfig!!
              @"User-Agent": [@"iOS/" stringByAppendingString:kClientVersion] };
}

- (void)stopEventSource {
    @synchronized (self) {
        DEBUG_LOGX(@"EnvironmentController stopping event source.");
        [self.eventSource close];
        self.eventSource = nil;
    }
}

- (void)handlePingEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypePing]) { return; }
    [self syncWithServerForConfig];
}

- (void)handlePutEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypePut]) { return; }
    if (event.data.length == 0) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE put event missing data"];
        return;
    }
    NSDictionary *newConfigDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    if (!newConfigDictionary) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE put event json could not be read"];
        return;
    }

    LDFlagConfigModel *newConfig = [[LDFlagConfigModel alloc] initWithDictionary:newConfigDictionary];

    NSString *updateResultNotificationName = [self.user.flagConfig isEqualToConfig:newConfig] ? kLDUserNoChangeNotification : kLDUserUpdatedNotification;
    [self postFeatureFlagsChangedNotificationForChangedFlagKeys:[self.user.flagConfig differingFlagKeysFromConfig:newConfig]];
    self.user.flagConfig = newConfig;
    [self.dataManager saveUser:self.user];
    [self reportFlagConfigProcessingCompleteWithNotificationName:updateResultNotificationName message:@"SSE put event complete"];
}

- (void)handlePatchEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypePatch]) { return; }
    if (event.data.length == 0) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE patch event missing data"];
        return;
    }
    NSDictionary *patchDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    if (!patchDictionary) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE patch event json could not be read"];
        return;
    }

    LDFlagConfigModel *originalFlagConfig = [self.user.flagConfig copy];

    [self.user.flagConfig addOrReplaceFromDictionary:patchDictionary];

    if ([self.user.flagConfig hasFeaturesEqualToDictionary:originalFlagConfig.dictionaryValue]) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE patch event did not change feature flag value"];
        return;
    }

    [self postFeatureFlagsChangedNotificationForChangedFlagKeys:[originalFlagConfig differingFlagKeysFromConfig:self.user.flagConfig]];
    [self.dataManager saveUser:self.user];
    [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserUpdatedNotification message:@"SSE patch event complete"];
}

- (void)handleDeleteEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypeDelete]) { return; }
    if (event.data.length == 0) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE delete event missing data"];
        return;
    }
    NSDictionary *deleteDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    if (!deleteDictionary) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE delete event json could not be read"];
        return;
    }

    LDFlagConfigModel *originalFlagConfig = [self.user.flagConfig copy];

    [self.user.flagConfig deleteFromDictionary:deleteDictionary];

    if ([self.user.flagConfig hasFeaturesEqualToDictionary:originalFlagConfig.dictionaryValue]) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"SSE delete event did not change feature flags"];
        return;
    }

    [self.dataManager saveUser:self.user];
    [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserUpdatedNotification message:@"SSE delete event complete"];
}

#pragma mark - Polling

- (void)backgroundFetchInitiated {
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.backgroundTime];
    if (time >= [self.config.backgroundFetchInterval doubleValue]) {
        [self syncWithServerForConfig];
    }
}

-(void)syncWithServerForConfig {
    if (!self.isOnline) {
        DEBUG_LOGX(@"EnvironmentController is in offline mode so won't sync config with server");
        return;
    }
    
    if (!self.user) {
        DEBUG_LOGX(@"EnvironmentController has no user so won't sync config with server");
        return;
    }

    [self.requestManager performFeatureFlagRequest:self.user isOnline:self.isOnline];
}

- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary {
    if (!success) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDServerConnectionUnavailableNotification message:@"flag request failed"];
        return;
    }
    
    //success without json means a 304 Not Modified
    if (jsonConfigDictionary == nil) {
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:@"not modified"];
        return;
    }

    LDFlagConfigModel *newConfig = [[LDFlagConfigModel alloc] initWithDictionary:jsonConfigDictionary];
    if (!newConfig || [self.user.flagConfig isEqualToConfig:newConfig]) {
        [self.user.flagConfig updateEventTrackingContextFromConfig:newConfig];
        //Notify interested clients and bail out if no new config, or the new config equals the existing config
        NSString *message = newConfig == nil ? @"unable to create new flag config from json" : @"feature flags unchanged";
        [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserNoChangeNotification message:message];
        return;
    }

    [self postFeatureFlagsChangedNotificationForChangedFlagKeys:[self.user.flagConfig differingFlagKeysFromConfig:newConfig]];
    self.user.flagConfig = newConfig;
    [self.dataManager saveUser:self.user];
    [self reportFlagConfigProcessingCompleteWithNotificationName:kLDUserUpdatedNotification message:@"flag request complete."];
}

#pragma mark - Flag Config Processing Notification

-(void)postFeatureFlagsChangedNotificationForChangedFlagKeys:(NSArray<NSString*>*)flagKeys {
    if (flagKeys == nil || flagKeys.count == 0) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kLDFeatureFlagsChangedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey,
                                                                                                                        kLDNotificationUserInfoKeyFlagKeys:flagKeys}];
    DEBUG_LOG(@"EnvironmentController for mobileKey:%@ posted %@ for flagKeys:%@", self.mobileKey, kLDFeatureFlagsChangedNotification, [flagKeys description]);
}

-(void)reportFlagConfigProcessingCompleteWithNotificationName:(NSString*)notificationName message:(NSString*)message {
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];
    DEBUG_LOG(@"EnvironmentController for mobileKey:%@ posted %@%@%@.", self.mobileKey, notificationName, message.length > 0 ? @", " : @"", message ?: @"");
}

#pragma mark - Events

-(void)syncWithServerForEvents {
    if (!self.isOnline) {
        DEBUG_LOGX(@"EnvironmentController is in offline mode so won't sync events with server");
        return;
    }

    DEBUG_LOGX(@"EnvironmentController syncing events with server");

    [self.dataManager recordSummaryEventWithTracker:self.user.flagConfigTracker];

    __weak typeof(self) weakSelf = self;
    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.user resetTracker];
        if (eventDictionaries.count == 0) {
            DEBUG_LOGX(@"EnvironmentController has no events so won't sync events with server");
            return;
        }
        [strongSelf.requestManager performEventRequest:eventDictionaries isOnline:self.isOnline];
    }];
}

- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray responseDate:(NSDate*)responseDate {
    if (!success) {
        return;
    }
    DEBUG_LOGX(@"EnvironmentController processedEvents method called after receiving successful response from server");
    [self.dataManager deleteProcessedEvents:jsonEventArray];
    self.dataManager.lastEventResponseDate = responseDate;
}

- (void)flushEvents {
    if (!self.isOnline) {
        DEBUG_LOGX(@"EnvironmentController flushEvents aborted - manager is offline");
        return;
    }
    [self syncWithServerForEvents];
}

@end

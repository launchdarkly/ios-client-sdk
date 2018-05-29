//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDClientManager.h"
#import "LDClient.h"
#import "LDPollingManager.h"
#import "LDDataManager.h"
#import "LDUtil.h"
#import "LDUserModel.h"
#import "LDEventModel.h"
#import "LDFlagConfigModel.h"
#import "NSDictionary+JSON.h"
#import <DarklyEventSource/LDEventSource.h>
#import "LDEvent+Unauthorized.h"
#import "LDEvent+EventTypes.h"

NSString * const kLDClientManagerStreamMethod = @"meval";

@interface LDClientManager()

@property(nonatomic, strong, readonly) LDEventSource *eventSource;
@property(nonatomic, strong) NSDate *backgroundTime;

@end

@implementation LDClientManager {
    BOOL _online;
}

@synthesize eventSource;

+(LDClientManager *)sharedInstance {
    static LDClientManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
#if TARGET_OS_IOS || TARGET_OS_TV
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
#elif TARGET_OS_OSX
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterForeground) name:NSApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterBackground) name:NSApplicationWillResignActiveNotification object:nil];
#endif
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(backgroundFetchInitiated) name:kLDBackgroundFetchInitiated object:nil];
        
    });
    return sharedApiManager;
}

- (void)setOnline:(BOOL)online {
    _online = online;
    _online ? [self startPolling] : [self stopPolling];
}

- (BOOL)isOnline {
    return _online;
}

- (void)startPolling {
    if (!self.isOnline) {
        DEBUG_LOGX(@"ClientManager startPolling aborted - manager is offline");
        return;
    }

    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    LDConfig *config = [[LDClient sharedInstance] ldConfig];

    [pollingMgr startEventPolling];
    
    if ([config streaming]) {
        [self configureEventSource];
    }
    else{
        [self syncWithServerForConfig];
        [pollingMgr startConfigPolling];
    }
}


- (void)stopPolling {
    DEBUG_LOGX(@"ClientManager stopPolling method called");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr stopEventPolling];
    
    if ([[[LDClient sharedInstance] ldConfig] streaming]) {
        [self stopEventSource];
    }
    else{
        [pollingMgr stopConfigPolling];
    }
    
    [self flushEvents];
}

-(void)updateUser {
    if (!self.isOnline) {
        DEBUG_LOGX(@"ClientManager updateUser aborted - manager is offline");
        return;
    }
    if (self.eventSource) {
        [self stopEventSource];
    }
    [[LDPollingManager sharedInstance] stopConfigPolling];

    if ([[[LDClient sharedInstance] ldConfig] streaming]) {
        [self configureEventSource];
    } else {
        [self syncWithServerForConfig];
        [[LDPollingManager sharedInstance] startConfigPolling];
    }
}

- (void)willEnterBackground {
    DEBUG_LOGX(@"ClientManager entering background");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr suspendEventPolling];
    
    if ([[[LDClient sharedInstance] ldConfig] streaming]) {
        [self stopEventSource];
    }
    else{
        [pollingMgr suspendConfigPolling];
    }
    
    [self flushEvents];
    
    self.backgroundTime = [NSDate date];
    
}

- (void)willEnterForeground {
    DEBUG_LOGX(@"ClientManager entering foreground");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    [pollingMgr resumeEventPolling];
    
    LDClient *client = [LDClient sharedInstance];
    
    if ([[client ldConfig] streaming]) {
        [self configureEventSource];
    }
    else{
        [pollingMgr resumeConfigPolling];
    }
}

- (void)configureEventSource {
    @synchronized (self) {
        if (!self.isOnline) {
            DEBUG_LOGX(@"ClientManager configureEventSource aborted - manager is offline");
            return;
        }

        if (eventSource) {
            DEBUG_LOGX(@"ClientManager aborting event source creation - event source running");
            return;
        }

        eventSource = [self eventSourceForUser:[LDClient sharedInstance].ldUser config:[LDClient sharedInstance].ldConfig httpHeaders:[self httpHeadersForEventSource]];

        __weak typeof(self) weakSelf = self;
        [eventSource onMessage:^(LDEvent *event) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf handlePingEvent:event];
            [strongSelf handlePutEvent:event];
            [strongSelf handlePatchEvent:event];
            [strongSelf handleDeleteEvent:event];
        }];

        [eventSource onError:^(LDEvent *event) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kLDServerConnectionUnavailableNotification object:nil];
            if (![event isUnauthorizedEvent]) { return; }
            [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil];
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
    NSString *eventStreamUrl = [config.streamUrl stringByAppendingPathComponent:kLDClientManagerStreamMethod];
    if (!config.useReport) {
        NSString *encodedUser = [LDUtil base64UrlEncodeString:[[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString]];
        eventStreamUrl = [eventStreamUrl stringByAppendingPathComponent:encodedUser];
    }
    return [NSURL URLWithString:eventStreamUrl];
}

- (void)handlePingEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypePing]) { return; }
    [self syncWithServerForConfig];
}

- (void)handlePutEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypePut]) { return; }
    if (event.data.length == 0) {
        DEBUG_LOGX(@"ClientManager aborted handlePutEvent - event contains no data");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }
    NSDictionary *newConfigDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    if (!newConfigDictionary) {
        DEBUG_LOGX(@"ClientManager aborted handlePutEvent - event contains json data could not be read");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }

    LDFlagConfigModel *newConfig = [[LDFlagConfigModel alloc] initWithDictionary:newConfigDictionary];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];

    NSString *updateResultNotificationName = [user.flagConfig isEqualToConfig:newConfig] ? kLDUserNoChangeNotification : kLDUserUpdatedNotification;
    user.flagConfig = newConfig;
    [[LDDataManager sharedManager] saveUser:user];
    [[NSNotificationCenter defaultCenter] postNotificationName:updateResultNotificationName object:nil];
    DEBUG_LOG(@"ClientManager posted %@ following user config update from SSE put event", updateResultNotificationName);
}

- (void)handlePatchEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypePatch]) { return; }
    if (event.data.length == 0) {
        DEBUG_LOGX(@"ClientManager aborted handlePatchEvent - event contains no data");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }
    NSDictionary *patchDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    if (!patchDictionary) {
        DEBUG_LOGX(@"ClientManager aborted handlePatchEvent - event json data could not be read");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    NSDictionary *originalFlagConfig = user.flagConfig.featuresJsonDictionary;

    [user.flagConfig addOrReplaceFromDictionary:patchDictionary];

    if ([user.flagConfig hasFeaturesEqualToDictionary:originalFlagConfig]) {
        DEBUG_LOGX(@"ClientManager handlePatchEvent resulted in no change to the flag config");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }

    [[LDDataManager sharedManager] saveUser:user];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserUpdatedNotification object:nil];
    DEBUG_LOGX(@"ClientManager posted Darkly.UserUpdatedNotification following user config update from SSE patch event");
}

- (void)handleDeleteEvent:(LDEvent*)event {
    if (![event.event isEqualToString:kLDEventTypeDelete]) { return; }
    if (event.data.length == 0) {
        DEBUG_LOGX(@"ClientManager aborted handleDeleteEvent - event contains no data");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }
    NSDictionary *deleteDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    if (!deleteDictionary) {
        DEBUG_LOGX(@"ClientManager aborted handleDeleteEvent - event json data could not be read");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    NSDictionary *originalFlagConfig = user.flagConfig.featuresJsonDictionary;

    [user.flagConfig deleteFromDictionary:deleteDictionary];

    if ([user.flagConfig hasFeaturesEqualToDictionary:originalFlagConfig]) {
        DEBUG_LOGX(@"ClientManager handleDeleteEvent resulted in no change to the flag config");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];
        return;
    }

    [[LDDataManager sharedManager] saveUser:user];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserUpdatedNotification object:nil];
    DEBUG_LOGX(@"ClientManager posted Darkly.UserUpdatedNotification following user config update from SSE delete event");
}

- (void)postClientUnauthorizedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil];
}

- (void)stopEventSource {
    @synchronized (self) {
        DEBUG_LOGX(@"ClientManager stopping event source.");
        [eventSource close];
        eventSource = nil;
    }
}

- (void)backgroundFetchInitiated {
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:self.backgroundTime];
    LDConfig *config = [[LDClient sharedInstance] ldConfig];
    if (time >= [config.backgroundFetchInterval doubleValue]) {
        [self syncWithServerForConfig];
    }
}

-(void)syncWithServerForEvents {
    if (!self.isOnline) {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync events with server");
        return;
    }

    DEBUG_LOGX(@"ClientManager syncing events with server");

    [[LDDataManager sharedManager] createSummaryEventWithTracker:[LDClient sharedInstance].ldUser.flagConfigTracker config:[LDClient sharedInstance].ldConfig];

    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
        [[LDClient sharedInstance].ldUser resetTracker];
        if (eventDictionaries) {
            [[LDRequestManager sharedInstance] performEventRequest:eventDictionaries];
        } else {
            DEBUG_LOGX(@"ClientManager has no events so won't sync events with server");
        }
    }];
}

-(void)syncWithServerForConfig {
    if (!self.isOnline) {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync config with server");
        return;
    }
    
    if (![LDClient sharedInstance].ldUser) {
        DEBUG_LOGX(@"ClientManager has no user so won't sync config with server");
        return;
    }

    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
}

- (void)flushEvents {
    if (!self.isOnline) {
        DEBUG_LOGX(@"ClientManager flushEvents aborted - manager is offline");
        return;
    }
    [self syncWithServerForEvents];
}

- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray responseDate:(NSDate*)responseDate {
    // If Success
    if (success) {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving successful response from server");
        // Audit cached events versus processed Events and only keep difference
        if (jsonEventArray) {
            [[LDDataManager sharedManager] deleteProcessedEvents:jsonEventArray];
        }
        [LDDataManager sharedManager].lastEventResponseDate = responseDate;
    }
}

- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary {
    if (!success) {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving failure response from server");
        [[NSNotificationCenter defaultCenter] postNotificationName: kLDServerConnectionUnavailableNotification
                                                            object: nil];
        return;
    }
    
    DEBUG_LOGX(@"ClientManager processedConfig method called after receiving successful response from server");

    LDFlagConfigModel *newConfig = [[LDFlagConfigModel alloc] initWithDictionary:jsonConfigDictionary];
    if (!newConfig || [[LDClient sharedInstance].ldUser.flagConfig isEqualToConfig:newConfig]) {
        [[LDClient sharedInstance].ldUser.flagConfig updateEventTrackingContextFromConfig:newConfig];
        //Notify interested clients and bail out if no new config, or the new config equals the existing config
        [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserNoChangeNotification
                                                            object: nil];
        DEBUG_LOGX(@"ClientManager posted Darkly.UserNoChangeNotification following user config update");
        return;
    }
    
    LDUserModel *user = [LDClient sharedInstance].ldUser;
    user.flagConfig = newConfig;
    [[LDDataManager sharedManager] saveUser:user];  // Save context
    
    [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserUpdatedNotification
                                                        object: nil];
    DEBUG_LOGX(@"ClientManager posted Darkly.UserUpdatedNotification following user config update");
}

- (NSDictionary *)httpHeadersForEventSource {
    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:[[[LDClient sharedInstance] ldConfig] mobileKey]];
    
    [headers setObject:authKey forKey:@"Authorization"];
    [headers setObject:[@"iOS/" stringByAppendingString:kClientVersion] forKey:@"User-Agent"];
    return headers;
}

@end

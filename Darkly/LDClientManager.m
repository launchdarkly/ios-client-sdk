//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDClientManager.h"
#import "LDPollingManager.h"
#import "LDDataManager.h"
#import "LDUtil.h"
#import "LDUserModel.h"
#import "LDEventModel.h"
#import "LDFlagConfigModel.h"
#import "NSDictionary+JSON.h"
#import "LDEventSource.h"

@interface LDClientManager()

@property(nonatomic, strong, readonly) LDEventSource *eventSource;
@property(nonatomic, strong) NSDate *backgroundTime;

@end

@implementation LDClientManager

@synthesize offlineEnabled, eventSource;

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

- (void)startPolling {
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    LDConfig *config = [[LDClient sharedInstance] ldConfig];
    pollingMgr.eventPollingIntervalMillis = [config.flushInterval intValue] * kMillisInSecs;
    DEBUG_LOG(@"ClientManager startPolling method called with pollingInterval=%f", pollingMgr.eventPollingIntervalMillis);
    [pollingMgr startEventPolling];
    
    if ([config streaming]) {
        [self configureEventSource];
    }
    else{
        [self syncWithServerForConfig];
        pollingMgr.configPollingIntervalMillis = [config.pollingInterval intValue] * kMillisInSecs;
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
        if (eventSource) {
            DEBUG_LOGX(@"ClientManager aborting event source creation - event source running");
            return;
        }
        eventSource = [LDEventSource eventSourceWithURL:[NSURL URLWithString:[LDClient sharedInstance].ldConfig.streamUrl] httpHeaders:[self httpHeadersForEventSource]];
        
        [eventSource onMessage:^(LDEvent *event) {
            if (![event.event isEqualToString:@"ping"]) { return; }
            [self syncWithServerForConfig];
        }];
    }
}

- (void)stopEventSource {
    @synchronized (self) {
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
    if (!offlineEnabled) {
        DEBUG_LOGX(@"ClientManager syncing events with server");
        
        [[LDDataManager sharedManager] allEventsJsonArray:^(NSArray *array) {
            if (array) {
                [[LDRequestManager sharedInstance] performEventRequest:array];
            } else {
                DEBUG_LOGX(@"ClientManager has no events so won't sync events with server");
            }
        }];
        
    } else {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync events with server");
    }
}

-(void)syncWithServerForConfig {
    if (offlineEnabled) {
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
    [self syncWithServerForEvents];
}

- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray {
    // If Success
    if (success) {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving successful response from server");
        // Audit cached events versus processed Events and only keep difference
        if (jsonEventArray) {
            [[LDDataManager sharedManager] deleteProcessedEvents: jsonEventArray];
        }
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
    if (!newConfig || [[LDClient sharedInstance].ldUser.config isEqualToConfig:newConfig]) {
        //Notify interested clients and bail out if no new config, or the new config equals the existing config
        [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserNoChangeNotification
                                                            object: nil];
        DEBUG_LOGX(@"ClientManager posted Darkly.UserNoChangeNotification following user config update");
        return;
    }
    
    LDUserModel *user = [LDClient sharedInstance].ldUser;
    user.config = newConfig;
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

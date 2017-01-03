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

@implementation LDClientManager

@synthesize offlineEnabled, eventSource;

+(LDClientManager *)sharedInstance {
    static LDClientManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(syncWithServerForConfig) name:kLDBackgroundFetchInitiated object:nil];
        
    });
    return sharedApiManager;
}

- (void)startPolling {
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    LDClient *client = [LDClient sharedInstance];
    LDConfig *config = client.ldConfig;
    pollingMgr.eventTimerPollingIntervalMillis = [config.flushInterval intValue] * kMillisInSecs;
    DEBUG_LOG(@"ClientManager startPolling method called with eventTimerPollingInterval=%f", pollingMgr.eventTimerPollingIntervalMillis);
    [pollingMgr startEventPolling];
    
    eventSource = [EventSource eventSourceWithURL:[NSURL URLWithString:kStreamUrl] mobileKey:config.mobileKey];
    
    [eventSource onMessage:^(Event *e) {
        [self syncWithServerForConfig];
    }];
}


- (void)stopPolling {
    DEBUG_LOGX(@"ClientManager stopPolling method called");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr stopEventPolling];
    
    [eventSource close];
    
    [self flushEvents];
}

- (void)willEnterBackground {
    DEBUG_LOGX(@"ClientManager entering background");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr suspendEventPolling];
    
    [eventSource close];
    
    [self flushEvents];
}

- (void)willEnterForeground {
    DEBUG_LOGX(@"ClientManager entering foreground");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    [pollingMgr resumeEventPolling];
    
    LDClient *client = [LDClient sharedInstance];
    eventSource = [EventSource eventSourceWithURL:[NSURL URLWithString:kStreamUrl] mobileKey:client.ldConfig.mobileKey];
    
    [eventSource onMessage:^(Event *e) {
        [self syncWithServerForConfig];
    }];
}

-(void)syncWithServerForEvents {
    if (!offlineEnabled) {
        DEBUG_LOGX(@"ClientManager syncing events with server");
        
        NSArray *eventJsonData = [[LDDataManager sharedManager] allEventsJsonArray];
        
        if (eventJsonData) {
            [[LDRequestManager sharedInstance] performEventRequest:eventJsonData];
        } else {
            DEBUG_LOGX(@"ClientManager has no events so won't sync events with server");
        }
    } else {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync events with server");
    }
}

-(void)syncWithServerForConfig {
    if (!offlineEnabled) {
        DEBUG_LOGX(@"ClientManager syncing config with server");
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.ldUser;
        
        if (currentUser) {
            NSString *jsonString = [currentUser convertToJson];
            if (jsonString) {
                NSString *encodedUser = [LDUtil base64EncodeString:jsonString];
                [[LDRequestManager sharedInstance] performFeatureFlagRequest:encodedUser];
            } else {
                DEBUG_LOGX(@"ClientManager is not able to convert user to json");
            }
        } else {
            DEBUG_LOGX(@"ClientManager has no user so won't sync config with server");
        }
    } else {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync config with server");
    }
}

- (void)flushEvents {
    [self syncWithServerForEvents];
}

- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray eventIntervalMillis:(int)eventIntervalMillis {
    // If Success
    if (success) {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving successful response from server");
        // Audit cached events versus processed Events and only keep difference
        if (jsonEventArray) {
            [[LDDataManager sharedManager] deleteProcessedEvents: jsonEventArray];
        }
    } else {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving failure response from server");
        LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
        DEBUG_LOG(@"ClientManager setting event interval to: %d", eventIntervalMillis);
        pollingMgr.eventTimerPollingIntervalMillis = eventIntervalMillis;
    }
}

- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary {
    if (success) {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving successful response from server");
        // If Success
        LDFlagConfigModel *newConfig = [[LDFlagConfigModel alloc] initWithDictionary:jsonConfigDictionary];
        
        if (newConfig) {
            // Overwrite Config with new config
            LDClient *client = [LDClient sharedInstance];
            LDUserModel *user = client.ldUser;
            user.config = newConfig;
            // Save context
            [[LDDataManager sharedManager] saveUser:user];
            
            [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserUpdatedNotification
                                                                object: nil];
        }
    } else {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving failure response from server");
    }
}

@end

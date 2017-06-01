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
#import "EventSource.h"

@interface LDClientManager()

@property(nonatomic, strong, readonly) EventSource *eventSource;
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
        eventSource = [EventSource eventSourceWithURL:[NSURL URLWithString:kStreamUrl] mobileKey:config.mobileKey timeoutInterval:[config.connectionTimeout doubleValue]];
        
        [eventSource onMessage:^(Event *e) {
            [self syncWithServerForConfig];
        }];
    }
    else{
        pollingMgr.configPollingIntervalMillis = [config.pollingInterval intValue] * kMillisInSecs;
        [pollingMgr startConfigPolling];
    }
}


- (void)stopPolling {
    DEBUG_LOGX(@"ClientManager stopPolling method called");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr stopEventPolling];
    
    if ([[[LDClient sharedInstance] ldConfig] streaming]) {
        [eventSource close];
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
        [eventSource close];
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
        eventSource = [EventSource eventSourceWithURL:[NSURL URLWithString:kStreamUrl] mobileKey:client.ldConfig.mobileKey];
        
        [eventSource onMessage:^(Event *e) {
            [self syncWithServerForConfig];
        }];
    }
    else{
        [pollingMgr resumeConfigPolling];
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

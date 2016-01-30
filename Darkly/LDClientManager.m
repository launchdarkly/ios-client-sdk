//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDClientManager.h"
#import "LDPollingManager.h"
#import "LDDataManager.h"
#import "LDUtil.h"
#import "LDUser.h"
#import "LDEvent.h"
#import "NSDictionary+JSON.h"

@implementation LDClientManager

@synthesize offlineEnabled;

NSString *const kLDUserUpdatedNotification = @"Darkly.UserUpdatedNotification";

+(LDClientManager *)sharedInstance {
    static LDClientManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        
    });
    return sharedApiManager;
}

- (void)startPolling {
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    LDClient *client = [LDClient sharedInstance];
    LDConfig *config = client.ldConfig;
    pollingMgr.eventTimerPollingIntervalMillis = [config.flushInterval intValue] * kMillisInSecs;
    DEBUG_LOG(@"ClientManager startPolling method called with configurationTimerPollingInterval=%f and eventTimerPollingInterval=%f", pollingMgr.configurationTimerPollingIntervalMillis, pollingMgr.eventTimerPollingIntervalMillis);
    [pollingMgr startConfigPolling];
    [pollingMgr startEventPolling];
}


- (void)stopPolling {
    DEBUG_LOGX(@"ClientManager stopPolling method called");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr stopConfigPolling];
    [pollingMgr stopEventPolling];
    
    [self flushEvents];
}

- (void)willEnterBackground {
    DEBUG_LOGX(@"ClientManager entering background");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    
    [pollingMgr suspendConfigPolling];
    [pollingMgr suspendEventPolling];
    
    [self flushEvents];
}

- (void)willEnterForeground {
    DEBUG_LOGX(@"ClientManager entering foreground");
    LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
    [pollingMgr resumeConfigPolling];
    [pollingMgr resumeEventPolling];
}

-(void)syncWithServerForEvents {
    if (!offlineEnabled) {
        DEBUG_LOGX(@"ClientManager syncing events with server");
        
        NSData *eventJsonData = [[LDDataManager sharedManager] allEventsJsonData];
        
        if (eventJsonData) {
            LDRequestManager *rMan = [LDRequestManager sharedInstance];
            [rMan performEventRequest:eventJsonData];
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
        LDUser *currentUser = client.user;
        
        if (currentUser) {
            NSDictionary *jsonDictionary = [MTLJSONAdapter JSONDictionaryFromModel:currentUser error: nil];
            NSString *jsonString = [jsonDictionary ld_jsonString];
            NSString *encodedUser = [LDUtil base64EncodeString:jsonString];
            [[LDRequestManager sharedInstance] performFeatureFlagRequest:encodedUser];
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

- (void)processedEvents:(BOOL)success jsonEventArray:(NSData *)jsonEventArray eventIntervalMillis:(int)eventIntervalMillis {
    // If Success
    if (success) {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving successful response from server");
        // Audit cached events versus processed Events and only keep difference
        NSArray *processedJsonArray = [NSJSONSerialization JSONObjectWithData:jsonEventArray options:NSJSONReadingMutableContainers error:nil];
        if (processedJsonArray) {
            [[LDDataManager sharedManager] deleteProcessedEvents: processedJsonArray];
        }
    } else {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving failure response from server");
        LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
        DEBUG_LOG(@"ClientManager setting event interval to: %d", eventIntervalMillis);
        pollingMgr.eventTimerPollingIntervalMillis = eventIntervalMillis;
    }
}

- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary configIntervalMillis:(int)configIntervalMillis {
    if (success) {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving successful response from server");
        // If Success
        LDFlagConfig *newConfig = [MTLJSONAdapter modelOfClass:[LDFlagConfig class]
                                            fromJSONDictionary:jsonConfigDictionary
                                                         error: nil];
        if (newConfig) {
            // Overwrite Config with new config
            LDClient *client = [LDClient sharedInstance];
            LDUser *user = client.user;
            UserEntity *userEntity = [[LDDataManager sharedManager] findUserEntityWithkey: user.key];
            
            user.config = newConfig;
            newConfig.userKey = user.key;
            ConfigEntity *configEntity = [MTLManagedObjectAdapter managedObjectFromModel:newConfig
                                                                    insertingIntoContext:[[LDDataManager sharedManager] managedObjectContext]
                                                                                   error: nil];
            userEntity.config = configEntity;
            
            // Save context
            [[LDDataManager sharedManager] saveContext];
            
            // Update polling interval for Config for new config interval
            LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
            DEBUG_LOG(@"ClientManager setting config interval to: %d", configIntervalMillis);
            pollingMgr.configurationTimerPollingIntervalMillis = configIntervalMillis;
            
            [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserUpdatedNotification
                                                                object: nil];
        }
    } else {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving failure response from server");
        LDPollingManager *pollingMgr = [LDPollingManager sharedInstance];
        DEBUG_LOG(@"ClientManager setting config interval to: %d", configIntervalMillis);
        pollingMgr.configurationTimerPollingIntervalMillis = configIntervalMillis;
    }
}

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "ClientManager.h"
#import "PollingManager.h"
#import "DataManager.h"
#import "DarklyUtil.h"
#import "User.h"
#import "Event.h"
#import <BlocksKit/BlocksKit.h>
#import "NSDictionary+JSON.h"

@implementation ClientManager

@synthesize offlineEnabled;

NSString *const kLDUserUpdatedNotification = @"Darkly.UserUpdatedNotification";

+(ClientManager *)sharedInstance
{
    static ClientManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedApiManager selector:@selector(willEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        
    });
    return sharedApiManager;
}



- (void)startPolling
{
    PollingManager *pollingMgr = [PollingManager sharedInstance];
    
    LDClient *client = [LDClient sharedInstance];
    LDConfig *config = client.ldConfig;
    pollingMgr.eventTimerPollingInterval = [config.flushInterval intValue];
    // Need to pull the configurationTimerPollingInterval out of persisted data
    //pollingMgr.configurationTimerPollingInterval = kDefaultConfigCheckInterval;
    DEBUG_LOG(@"ClientManager startPolling method called with configurationTimerPollingInterval=%f and eventTimerPollingInterval=%f", pollingMgr.configurationTimerPollingInterval, pollingMgr.eventTimerPollingInterval);
    [pollingMgr startConfigPolling];
    [pollingMgr startEventPolling];
}


- (void)stopPolling
{
    DEBUG_LOGX(@"ClientManager stopPolling method called");
    PollingManager *pollingMgr = [PollingManager sharedInstance];
    
    [pollingMgr stopConfigPolling];
    [pollingMgr stopEventPolling];
    
    [self flushEvents];
}

- (void)willEnterBackground
{
    DEBUG_LOGX(@"ClientManager entering background");
    PollingManager *pollingMgr = [PollingManager sharedInstance];
    
    [pollingMgr suspendConfigPolling];
    [pollingMgr suspendEventPolling];
    
    [self flushEvents];
}

- (void)willEnterForeground
{
    DEBUG_LOGX(@"ClientManager entering foreground");
    PollingManager *pollingMgr = [PollingManager sharedInstance];
    [pollingMgr resumeConfigPolling];
    [pollingMgr resumeEventPolling];
}

-(void)syncWithServerForEvents
{
    if (!offlineEnabled) {
        DEBUG_LOGX(@"ClientManager syncing events with server");
        
        NSData *eventJsonData = [[DataManager sharedManager] allEventsJsonData];
        
        if (eventJsonData) {
            RequestManager *rMan = [RequestManager sharedInstance];
            [rMan performEventRequest:eventJsonData];
        } else {
            DEBUG_LOGX(@"ClientManager has no events so won't sync events with server");
        }
    } else {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync events with server");
    }
}

-(void)syncWithServerForConfig
{
    if (!offlineEnabled) {
        DEBUG_LOGX(@"ClientManager syncing config with server");
        LDClient *client = [LDClient sharedInstance];
        User *currentUser = client.user;
        
        if (currentUser) {
            NSDictionary *jsonDictionary = [MTLJSONAdapter JSONDictionaryFromModel:currentUser error: nil];
            NSString *jsonString = [jsonDictionary ld_jsonString];
            NSString *encodedUser = [DarklyUtil base64EncodeString:jsonString];
            [[RequestManager sharedInstance] performFeatureFlagRequest:encodedUser];
        } else {
            DEBUG_LOGX(@"ClientManager has no user so won't sync config with server");
        }
    } else {
        DEBUG_LOGX(@"ClientManager is in offline mode so won't sync config with server");
    }
}

- (void)flushEvents
{
    [self syncWithServerForEvents];
}

- (void)processedEvents:(BOOL)success jsonEventArray:(NSData *)jsonEventArray eventInterval:(int)eventInterval
{
    // If Success
    if (success) {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving successful response from server");
        // Audit cached events versus processed Events and only keep difference
        NSArray *processedJsonArray = [NSJSONSerialization JSONObjectWithData:jsonEventArray options:NSJSONReadingMutableContainers error:nil];
        if (processedJsonArray) {
            BOOL hasMatchedEvents = NO;
            
            // Loop through processedEvents
            for (NSDictionary *processedEventDict in processedJsonArray) {
                // Attempt to find match in currentEvents based on creationDate
                
                Event *processedEvent = [MTLJSONAdapter modelOfClass:[Event class]
                                                  fromJSONDictionary:processedEventDict
                                                               error:nil];
                NSManagedObject *matchedCurrentEvent = [[DataManager sharedManager] findEvent: [processedEvent creationDate]];
                // If events match
                if (matchedCurrentEvent) {
                    [[[DataManager sharedManager] managedObjectContext] deleteObject:matchedCurrentEvent];
                    hasMatchedEvents = YES;
                }
            }
            // If number of managedObjects is greater than 0, then Save Context
            if (hasMatchedEvents) {
                [[DataManager sharedManager] saveContext];
            }
        }
    } else {
        DEBUG_LOGX(@"ClientManager processedEvents method called after receiving failure response from server");
        PollingManager *pollingMgr = [PollingManager sharedInstance];
        DEBUG_LOG(@"ClientManager setting event interval to: %d", eventInterval);
        pollingMgr.eventTimerPollingInterval = eventInterval;
    }
}

- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary configInterval:(int)configInterval
{
    if (success) {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving successful response from server");
        // If Success
        Config *config = [MTLJSONAdapter modelOfClass:[Config class]
                                   fromJSONDictionary:jsonConfigDictionary
                                                error: nil];
        if (config) {
            // Overwrite Config with new config
            LDClient *client = [LDClient sharedInstance];
            User *user = client.user;
            config.user = user;
            
            // Save context
            [MTLManagedObjectAdapter managedObjectFromModel:config
                                       insertingIntoContext:[[DataManager sharedManager] managedObjectContext]
                                                      error: nil];
            [[DataManager sharedManager] deleteOrphanedConfig];
            [[DataManager sharedManager] saveContext];
            // Update polling interval for Config for new config interval
            PollingManager *pollingMgr = [PollingManager sharedInstance];
            DEBUG_LOG(@"ClientManager setting config interval to: %d", configInterval);
            pollingMgr.configurationTimerPollingInterval = configInterval;
            
            [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserUpdatedNotification
                                                                object: nil];
        }
    } else {
        DEBUG_LOGX(@"ClientManager processedConfig method called after receiving failure response from server");
        PollingManager *pollingMgr = [PollingManager sharedInstance];
        DEBUG_LOG(@"ClientManager setting config interval to: %d", configInterval);
        pollingMgr.configurationTimerPollingInterval = configInterval;
    }
}

@end

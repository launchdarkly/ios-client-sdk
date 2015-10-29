//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDClient.h"
#import "ClientManager.h"
#import "DarklyUtil.h"
#import "DataManager.h"
#import "PollingManager.h"

@interface LDClient() {
    BOOL clientStarted;
}
@end

@implementation LDClient

@synthesize user, ldConfig;

+(LDClient *)sharedInstance
{
    static LDClient *sharedLDClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLDClient = [[self alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(configUpdated)
                                                     name: kLDUserUpdatedNotification object: nil];
    });
    return sharedLDClient;
}

- (BOOL)start:(LDConfigBuilder *)inputConfigBuilder userBuilder:(LDUserBuilder *)inputUserBuilder {
    DEBUG_LOGX(@"LDClient start method called");
    if (!clientStarted) {
        if (inputConfigBuilder) {
            ldConfig = [inputConfigBuilder build];
            if (ldConfig) {
                DarklyLogLevel logLevel =  DarklyLogLevelCriticalOnly;
                if ([ldConfig debugEnabled]) {
                    logLevel = DarklyLogLevelDebug;
                }
                [DarklyUtil setLogLevel:logLevel];
                
                clientStarted = YES;
                DEBUG_LOGX(@"LDClient started");
                if (!inputUserBuilder) {
                    inputUserBuilder = [[LDUserBuilder alloc] init];
                }
                user = [inputUserBuilder build];

                ClientManager *clientManager = [ClientManager sharedInstance];
                [clientManager syncWithServerForConfig];
                [clientManager startPolling];
                return YES;
            } else {
                DEBUG_LOGX(@"LDClient client requires a config to start");
                return NO;
            }
        } else {
            DEBUG_LOGX(@"LDClient client requires a config to start");
            return NO;
        }
    } else {
        DEBUG_LOGX(@"LDClient client already started");
        return NO;
    }
}

- (BOOL)updateUser:(LDUserBuilder *)builder {
    DEBUG_LOGX(@"LDClient updateUser method called");
    if (clientStarted) {
        if (builder) {
            user = [LDUserBuilder compareNewBuilder:builder withUser:user];
            ClientManager *clientManager = [ClientManager sharedInstance];
            [clientManager syncWithServerForConfig];
            return YES;
        } else {
            DEBUG_LOGX(@"LDClient updateUser needs a non-nil LDUserBuilder object");
            return NO;
        }
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

- (LDUserBuilder *)currentUserBuilder {
    DEBUG_LOGX(@"LDClient currentUserBuilder method called");
    if (clientStarted) {
        return [LDUserBuilder retrieveCurrentBuilder:user];
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return nil;
    }
}

- (BOOL)toggle:(NSString *)featureName default:(BOOL)defaultValue {
    DEBUG_LOG(@"LDClient toggle method called for feature=%@ and defaultValue=%d", featureName, defaultValue);
    if (clientStarted) {
        BOOL flagExists = [user doesFlagExist: featureName];
        BOOL flagValue = [user isFlagOn: featureName];
        BOOL returnValue = (flagExists ? flagValue : defaultValue);
        
        [[DataManager sharedManager] createFeatureEvent: featureName keyValue:returnValue defaultKeyValue:defaultValue];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return defaultValue;
}

- (BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary
{
    DEBUG_LOG(@"LDClient track method called for event=%@ and data=%@", eventName, dataDictionary);
    if (clientStarted) {
        [[DataManager sharedManager] createCustomEvent:eventName
                            withCustomValuesDictionary: dataDictionary];
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

- (BOOL)offline
{
    DEBUG_LOGX(@"LDClient offline method called");
    if (clientStarted) {
        ClientManager *clientManager = [ClientManager sharedInstance];
        [clientManager setOfflineEnabled:YES];
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

- (BOOL)online
{
    DEBUG_LOGX(@"LDClient online method called");
    if (clientStarted) {
        ClientManager *clientManager = [ClientManager sharedInstance];
        [clientManager setOfflineEnabled:NO];
        [clientManager syncWithServerForConfig];
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

- (BOOL)flush {
    DEBUG_LOGX(@"LDClient flush method called");
    if (clientStarted) {
        ClientManager *clientManager = [ClientManager sharedInstance];
        [clientManager flushEvents];
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

- (BOOL)stopClient {
    DEBUG_LOGX(@"LDClient stop method called");
    if (clientStarted) {
        ClientManager *clientManager = [ClientManager sharedInstance];
        [clientManager stopPolling];
        
        clientStarted = NO;
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

// Notification handler for ClientManager user updated
-(void)configUpdated {
    if (self.delegate && [self.delegate respondsToSelector:@selector(userDidUpdate)]) {
        [self.delegate userDidUpdate];        
    }
}

-(void)dealloc {
    self.delegate = nil;
}
@end

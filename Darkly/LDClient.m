//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDClient.h"
#import "LDClientManager.h"
#import "LDUtil.h"
#import "LDDataManager.h"
#import "LDPollingManager.h"
#import "DarklyConstants.h"

@interface LDClient() {
    BOOL clientStarted;
}
@end

@implementation LDClient

@synthesize ldUser, ldConfig;

+(LDClient *)sharedInstance
{
    static LDClient *sharedLDClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLDClient = [[self alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(userUpdated)
                                                     name: kLDUserUpdatedNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: sharedLDClient
                                                 selector:@selector(configFlagUpdated:)
                                                     name:kLDFlagConfigChangedNotification object:nil];
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
                [LDUtil setLogLevel:logLevel];
                
                clientStarted = YES;
                DEBUG_LOGX(@"LDClient started");
                if (!inputUserBuilder) {
                    inputUserBuilder = [[LDUserBuilder alloc] init];
                }
                ldUser = [inputUserBuilder build];
                
                LDClientManager *clientManager = [LDClientManager sharedInstance];
                [clientManager setOfflineEnabled:NO];
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
            ldUser = [LDUserBuilder compareNewBuilder:builder withUser:ldUser];
            LDClientManager *clientManager = [LDClientManager sharedInstance];
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
        return [LDUserBuilder retrieveCurrentBuilder:ldUser];
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
    if (clientStarted) {
        BOOL flagExists = [ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [ldUser flagValue: featureKey];
        BOOL returnValue = fallback;
        if ([flagValue isKindOfClass:[NSNumber class]] && flagExists) {
            returnValue = [(NSNumber *)flagValue boolValue];
        }
        
        [[LDDataManager sharedManager] createFeatureEvent: featureKey keyValue:[NSNumber numberWithBool:returnValue] defaultKeyValue:[NSNumber numberWithBool:fallback]];
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
    if (clientStarted) {
        BOOL flagExists = [ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [ldUser flagValue: featureKey];
        NSNumber *returnValue = fallback;
        if ([flagValue isKindOfClass:[NSNumber class]] && flagExists) {
            returnValue = (NSNumber *)flagValue;
        }
        
        [[LDDataManager sharedManager] createFeatureEvent: featureKey keyValue:returnValue defaultKeyValue:fallback];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return fallback;
}

- (NSString*)stringVariation:(NSString *)featureKey fallback:(NSString*)fallback{
    DEBUG_LOG(@"LDClient stringVariation method called for feature=%@ and fallback=%@", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (clientStarted) {
        BOOL flagExists = [ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [ldUser flagValue: featureKey];
        NSString *returnValue = fallback;
        if ([flagValue isKindOfClass:[NSString class]] && flagExists) {
            returnValue = (NSString *)flagValue;
        }
        
        [[LDDataManager sharedManager] createFeatureEvent: featureKey keyValue:returnValue defaultKeyValue:fallback];
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
    if (clientStarted) {
        BOOL flagExists = [ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [ldUser flagValue: featureKey];
        NSArray *returnValue = fallback;
        if ([flagValue isKindOfClass:[NSString class]] && flagExists) {
            returnValue = (NSArray *)flagValue;
        }
        
        [[LDDataManager sharedManager] createFeatureEvent: featureKey keyValue:returnValue defaultKeyValue:fallback];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return fallback;
}

- (NSDictionary*)dictionaryVariation:(NSString *)featureKey fallback:(NSDictionary*)fallback{
    DEBUG_LOG(@"LDClient dictionaryVariation method called for feature=%@ and fallback=%@", featureKey, fallback);
    if (![featureKey isKindOfClass:[NSString class]]) {
        NSLog(@"featureKey should be an NSString. Returning fallback value");
        return fallback;
    }
    if (clientStarted) {
        BOOL flagExists = [ldUser doesFlagExist: featureKey];
        NSObject *flagValue = [ldUser flagValue: featureKey];
        NSDictionary *returnValue = fallback;
        if ([flagValue isKindOfClass:[NSString class]] && flagExists) {
            returnValue = (NSDictionary *)flagValue;
        }
        
        [[LDDataManager sharedManager] createFeatureEvent: featureKey keyValue:returnValue defaultKeyValue:fallback];
        return returnValue;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
    }
    return fallback;
}

- (BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary
{
    DEBUG_LOG(@"LDClient track method called for event=%@ and data=%@", eventName, dataDictionary);
    if (clientStarted) {
        [[LDDataManager sharedManager] createCustomEvent:eventName
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
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager stopPolling];
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
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager setOfflineEnabled:NO];
        [clientManager startPolling];
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
    if (clientStarted) {
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager stopPolling];
        
        clientStarted = NO;
        return YES;
    } else {
        DEBUG_LOGX(@"LDClient not started yet!");
        return NO;
    }
}

// Notification handler for ClientManager user updated
-(void)userUpdated {
    if (self.delegate && [self.delegate respondsToSelector:@selector(userDidUpdate)]) {
        [self.delegate userDidUpdate];
    }
}

// Notification handler for DataManager config flag update
-(void)configFlagUpdated:(NSNotification *)notification {
    NSString *keyValue = [notification.userInfo objectForKey:@"flagkey"];
    if (self.delegate && [self.delegate respondsToSelector:@selector(featureFlagDidUpdate:)]) {
        [self.delegate featureFlagDidUpdate:keyValue];
    }
}

-(void)dealloc {
    self.delegate = nil;
}
@end

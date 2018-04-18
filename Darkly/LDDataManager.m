//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import "LDEventModel.h"
#import "LDUtil.h"

int const kUserCacheSize = 5;

static NSString * const kFlagKey = @"flagkey";

@interface LDDataManager()

@property (strong, atomic) NSMutableArray *eventsArray;

@end

@implementation LDDataManager

dispatch_queue_t eventsQueue;

+ (id)sharedManager {
    static LDDataManager *sharedDataManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataManager = [[self alloc] init];
        sharedDataManager.eventsArray = [[NSMutableArray alloc] init];
        eventsQueue = dispatch_queue_create("com.launchdarkly.EventQueue", NULL);
    });
    return sharedDataManager;
}

#pragma mark - users
-(void) purgeOldUser: (NSMutableDictionary *)dictionary {
    if (dictionary && [dictionary count] >= kUserCacheSize) {
        
        NSArray *sortedKeys = [dictionary keysSortedByValueUsingComparator: ^(LDUserModel *user1, LDUserModel *user2) {
            return [user1.updatedAt compare:user2.updatedAt];
        }];
        
        [dictionary removeObjectForKey:sortedKeys.firstObject];
    }
}

-(void) saveUser: (LDUserModel *) user {
    [self saveUser:user asDict:YES];
}

-(void) saveUserDeprecated:(LDUserModel *)user {
    [self saveUser:user asDict:NO];
}

-(void) saveUser:(LDUserModel *)user asDict:(BOOL)asDict {
    NSMutableDictionary *userDictionary = [self retrieveUserDictionary];
    if (userDictionary) {
        LDUserModel *resultUser = [userDictionary objectForKey:user.key];
        if (resultUser) {
            // User is found
            [self compareConfigForUser:resultUser withNewUser:user];
            resultUser = user;
            resultUser.updatedAt = [NSDate date];
        } else {
            // User is not found so need to create and purge old users
            [self compareConfigForUser:nil withNewUser:user];
            [self purgeOldUser: userDictionary];
            user.updatedAt = [NSDate date];
            [userDictionary setObject:user forKey:user.key];
        }
    } else {
        // No Dictionary exists so create
        [self compareConfigForUser:nil withNewUser:user];
        userDictionary = [[NSMutableDictionary alloc] init];
        [userDictionary setObject:user forKey:user.key];
    }
    [userDictionary setObject:user forKey:user.key];
    if (asDict) {
        [self storeUserDictionary:userDictionary];
    }
    else{
        [self deprecatedStoreUserDictionary:userDictionary];
    }
    
}

-(LDUserModel *)findUserWithkey: (NSString *)key {
    LDUserModel *resultUser = nil;
    NSDictionary *userDictionary = [self retrieveUserDictionary];
    if (userDictionary) {
        resultUser = [userDictionary objectForKey:key];
        if (resultUser) {
            resultUser.updatedAt = [NSDate date];
        }
    }
    return resultUser;
}

- (void)compareConfigForUser:(LDUserModel *)user withNewUser:(LDUserModel *)newUser {
    for (NSString *key in [newUser.config dictionaryValueIncludeNulls:NO]) {
        if(user == nil || ![[newUser.config configFlagValue:key] isEqual:[user.config configFlagValue:key]]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kLDFlagConfigChangedNotification object:nil userInfo:[NSDictionary dictionaryWithObject:key forKey:kFlagKey]];
        }
    }
}

- (void)storeUserDictionary:(NSDictionary *)userDictionary {
    NSMutableDictionary *archiveDictionary = [[NSMutableDictionary alloc] init];
    for (NSString *key in userDictionary) {
        if (![[userDictionary objectForKey:key] isKindOfClass:[LDUserModel class]]) { continue; }
        [archiveDictionary setObject:[[userDictionary objectForKey:key] dictionaryValueWithPrivateAttributesAndFlagConfig:YES] forKey:key];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:archiveDictionary forKey:kUserDictionaryStorageKey];
    [defaults synchronize];
}

- (void)deprecatedStoreUserDictionary:(NSDictionary *)userDictionary {
    NSMutableDictionary *archiveDictionary = [[NSMutableDictionary alloc] init];
    for (NSString *key in userDictionary) {
        NSData *userEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:(LDUserModel *)[userDictionary objectForKey:key]];
        [archiveDictionary setObject:userEncodedObject forKey:key];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:archiveDictionary forKey:kUserDictionaryStorageKey];
    [defaults synchronize];
}

- (NSMutableDictionary *)retrieveUserDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *encodedDictionary = [defaults objectForKey:kUserDictionaryStorageKey];
    NSMutableDictionary *retrievalDictionary = [[NSMutableDictionary alloc] initWithDictionary:encodedDictionary];
    for (NSString *key in encodedDictionary) {
        LDUserModel *decodedUser;
        if ([[encodedDictionary objectForKey:key] isKindOfClass:[NSData class]]) {
            decodedUser = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[encodedDictionary objectForKey:key]];
        }
        else{
            decodedUser = [[LDUserModel alloc] initWithDictionary:[encodedDictionary objectForKey:key]];
        }
        [retrievalDictionary setObject:decodedUser forKey:key];
    }
    return retrievalDictionary;
}

#pragma mark - events

-(void)createFeatureEventWithFlagKey:(NSString *)flagKey flagValue:(NSObject*)flagValue defaultFlagValue:(NSObject*)defaultFlagValue user:(LDUserModel*)user config:(LDConfig*)config {
    if([self isAtEventCapacity:_eventsArray]) {
        DEBUG_LOG(@"Events have surpassed capacity. Discarding feature event %@", flagKey);
        return;
    }
    DEBUG_LOG(@"Creating feature event for feature:%@ with value:%@ and fallback:%@", flagKey, flagValue, defaultFlagValue);
    [self addEventDictionary:[[LDEventModel featureEventWithFlagKey:flagKey
                                                       flagValue:flagValue
                                                defaultFlagValue:defaultFlagValue
                                                      userValue:user
                                                     inlineUser:config.inlineUserInEvents]
                              dictionaryValueUsingConfig:config]];
}

-(void)createCustomEventWithKey:(NSString *)eventKey customData:(NSDictionary *)customData user:(LDUserModel*)user config:(LDConfig*)config {
    if([self isAtEventCapacity:_eventsArray]) {
        DEBUG_LOG(@"Events have surpassed capacity. Discarding custom event %@ with customData %@", eventKey, customData);
        return;
    }
    DEBUG_LOG(@"Creating custom event for custom key:%@ and customData:%@", eventKey, customData);
    [self addEventDictionary:[[LDEventModel customEventWithKey:eventKey customData:customData userValue:user inlineUser:config.inlineUserInEvents] dictionaryValueUsingConfig:config]];
}

-(void)createIdentifyEventWithUser:(LDUserModel*)user config:(LDConfig*)config {
    if([self isAtEventCapacity:_eventsArray]) {
        DEBUG_LOG(@"Events have surpassed capacity. Discarding identify event for user key:%@", user.key);
        return;
    }
    DEBUG_LOG(@"Creating identify event for user key:%@", user.key);
    [self addEventDictionary:[[LDEventModel identifyEventWithUser:user] dictionaryValueUsingConfig:config]];
}

-(void)addEventDictionary:(NSDictionary*)eventDictionary {
    dispatch_async(eventsQueue, ^{
        if (!self.eventsArray) {
            self.eventsArray = [[NSMutableArray alloc] init];
        }
        if(![self isAtEventCapacity:self.eventsArray]) {
            [self.eventsArray addObject:eventDictionary];
        }
        else {
            DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@", eventDictionary[@"key"]);
        }
    });
}

-(BOOL)isAtEventCapacity:(NSArray *)currentArray {
    LDConfig *ldConfig = [[LDClient sharedInstance] ldConfig];
    return ldConfig.capacity && currentArray && [currentArray count] >= [ldConfig.capacity integerValue];
}

-(void) deleteProcessedEvents: (NSArray *) processedJsonArray {
    // Loop through processedEvents
    dispatch_async(eventsQueue, ^{
        NSInteger count = MIN([processedJsonArray count], [self.eventsArray count]);
        [self.eventsArray removeObjectsInRange:NSMakeRange(0, count)];
    });
}

-(void) allEventDictionaries:(void (^)(NSArray *))completion {
    dispatch_async(eventsQueue, ^{
        NSMutableArray *eventDictionaries = [self retrieveEventsArray];
        if (eventDictionaries && [eventDictionaries count]) {
            completion(eventDictionaries);
        } else {
            completion(nil);
        }
    });
}

-(void)flushEventsDictionary {
    [_eventsArray removeAllObjects];
}

- (NSMutableArray *)retrieveEventsArray {
    return [[NSMutableArray alloc] initWithArray:self.eventsArray];
}

@end

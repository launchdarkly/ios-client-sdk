//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import "LDEventModel.h"
#import "LDUtil.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigValue.h"
#import "LDEventTrackingContext.h"
#import "LDFlagConfigTracker.h"
#import "NSDate+ReferencedDate.h"
#import "NSThread+MainExecutable.h"

int const kUserCacheSize = 5;

static NSString * const kFlagKey = @"flagkey";

@interface LDDataManager()

@property (strong, atomic) NSMutableArray *eventsArray;

@end

@implementation LDDataManager

dispatch_queue_t saveUserQueue;
dispatch_queue_t eventsQueue;

+ (id)sharedManager {
    static LDDataManager *sharedDataManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataManager = [[self alloc] init];
        sharedDataManager.eventsArray = [[NSMutableArray alloc] init];
        saveUserQueue = dispatch_queue_create("com.launchdarkly.dataManager.saveUserQueue", DISPATCH_QUEUE_SERIAL);
        eventsQueue = dispatch_queue_create("com.launchdarkly.dataManager.eventQueue", DISPATCH_QUEUE_SERIAL);
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
    [self saveUser:user asDict:YES completion:nil];
}

-(void) saveUserDeprecated:(LDUserModel *)user {
    [self saveUser:user asDict:NO completion:nil];
}

-(void) saveUser:(LDUserModel *)user asDict:(BOOL)asDict completion:(void (^)(void))completion {
    LDUserModel *userCopy = [[LDUserModel alloc] initWithDictionary:[user dictionaryValueWithPrivateAttributesAndFlagConfig:YES]];      //Preserve the user while waiting to save on the saveQueue
    dispatch_async(saveUserQueue, ^{
        NSMutableDictionary *userDictionary = [self retrieveUserDictionary];
        if (userDictionary) {
            LDUserModel *resultUser = [userDictionary objectForKey:userCopy.key];
            if (resultUser) {
                // User is found
                [self compareConfigForUser:resultUser withNewUser:userCopy];
                userCopy.updatedAt = [NSDate date];
                userDictionary[userCopy.key] = userCopy;
            } else {
                // User is not found so need to create and purge old users
                [self compareConfigForUser:nil withNewUser:userCopy];
                [self purgeOldUser: userDictionary];
                userCopy.updatedAt = [NSDate date];
                userDictionary[userCopy.key] = userCopy;
            }
        } else {
            // No Dictionary exists so create
            [self compareConfigForUser:nil withNewUser:userCopy];
            userDictionary = [[NSMutableDictionary alloc] init];
            userDictionary[userCopy.key] = userCopy;
        }
        userDictionary[userCopy.key] = userCopy;
        if (asDict) {
            [self storeUserDictionary:userDictionary];
        }
        else{
            [self deprecatedStoreUserDictionary:userDictionary];
        }
        DEBUG_LOG(@"LDDataManager saved user:%@ %@", userCopy.key, userCopy);
        if (completion != nil) {
            [NSThread performOnMainThread:^{
                completion();
            }];
        }
    });
}

-(LDUserModel *)findUserWithkey: (NSString *)key {
    LDUserModel *resultUser = nil;
    NSDictionary *userDictionary = [self retrieveUserDictionary];
    if (userDictionary) {
        resultUser = [userDictionary objectForKey:key];
        if (resultUser) {
            DEBUG_LOG(@"LDDataManager found cached user:%@ %@", resultUser.key, resultUser);
            resultUser.updatedAt = [NSDate date];
        }
    }
    return resultUser;
}

- (void)compareConfigForUser:(LDUserModel *)user withNewUser:(LDUserModel *)newUser {
    for (NSString *key in [newUser.flagConfig dictionaryValueIncludeNulls:NO]) {
        if(user == nil || ![[newUser.flagConfig flagValueForFlagKey:key] isEqual:[user.flagConfig flagValueForFlagKey:key]]) {
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
        if (decodedUser == nil) {
            continue;
        }
        [retrievalDictionary setObject:decodedUser forKey:key];
    }
    return retrievalDictionary;
}

#pragma mark - events

-(void)createFlagEvaluationEventsWithFlagKey:(NSString*)flagKey
                           reportedFlagValue:(id)reportedFlagValue
                             flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                            defaultFlagValue:(id)defaultFlagValue
                                        user:(LDUserModel*)user
                                      config:(LDConfig*)config {
    [self createFeatureEventWithFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultFlagValue:defaultFlagValue user:user config:config];
    [self createDebugEventWithFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultFlagValue:defaultFlagValue user:user config:config];
    [user.flagConfigTracker logRequestForFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultValue:defaultFlagValue];
}

-(void)createFeatureEventWithFlagKey:(NSString*)flagKey
                   reportedFlagValue:(id)reportedFlagValue
                     flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                    defaultFlagValue:(id)defaultFlagValue
                                user:(LDUserModel*)user
                              config:(LDConfig*)config {
    if (!flagConfigValue.eventTrackingContext || (flagConfigValue.eventTrackingContext && !flagConfigValue.eventTrackingContext.trackEvents)) {
        DEBUG_LOG(@"Tracking is off. Discarding feature event %@", flagKey);
        return;
    }
    DEBUG_LOG(@"Creating feature event for feature:%@ with flagConfigValue:%@ and fallback:%@", flagKey, flagConfigValue, defaultFlagValue);
    [self addEventDictionary:[[LDEventModel featureEventWithFlagKey:flagKey
                                                  reportedFlagValue:reportedFlagValue
                                                    flagConfigValue:flagConfigValue
                                                   defaultFlagValue:defaultFlagValue
                                                               user:user
                                                         inlineUser:config.inlineUserInEvents]
                              dictionaryValueUsingConfig:config]];
}

-(void)createCustomEventWithKey:(NSString *)eventKey customData:(NSDictionary *)customData user:(LDUserModel*)user config:(LDConfig*)config {
    DEBUG_LOG(@"Creating custom event for custom key:%@ and customData:%@", eventKey, customData);
    [self addEventDictionary:[[LDEventModel customEventWithKey:eventKey customData:customData userValue:user inlineUser:config.inlineUserInEvents] dictionaryValueUsingConfig:config]];
}

-(void)createIdentifyEventWithUser:(LDUserModel*)user config:(LDConfig*)config {
    DEBUG_LOG(@"Creating identify event for user key:%@", user.key);
    [self addEventDictionary:[[LDEventModel identifyEventWithUser:user] dictionaryValueUsingConfig:config]];
}

-(void)createSummaryEventWithTracker:(LDFlagConfigTracker*)tracker config:(LDConfig*)config {
    if (!tracker.hasTrackedEvents) {
        DEBUG_LOGX(@"Tracker has no events to report. Discarding summary event.");
        return;
    }
    LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:tracker];
    if (summaryEvent == nil) {
        DEBUG_LOGX(@"Failed to create summary event. Aborting.");
        return;
    }
    DEBUG_LOGX(@"Creating summary event");
    [self addEventDictionary:[summaryEvent dictionaryValueUsingConfig:config]];
}

-(void)createDebugEventWithFlagKey:(NSString *)flagKey
                 reportedFlagValue:(id)reportedFlagValue
                   flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                  defaultFlagValue:(id)defaultFlagValue
                              user:(LDUserModel*)user
                            config:(LDConfig*)config {
    if (![self shouldCreateDebugEventForContext:flagConfigValue.eventTrackingContext lastEventResponseDate:self.lastEventResponseDate]) {
        DEBUG_LOG(@"LDDataManager createDebugEventWithFlagKey aborting, debug events are turned off. Discarding debug event %@", flagKey);
        return;
    }
    DEBUG_LOG(@"Creating debug event for feature:%@ with flagConfigValue:%@ and fallback:%@", flagKey, flagConfigValue, defaultFlagValue);
    [self addEventDictionary:[[LDEventModel debugEventWithFlagKey:flagKey
                                                reportedFlagValue:reportedFlagValue
                                                  flagConfigValue:flagConfigValue
                                                 defaultFlagValue:defaultFlagValue
                                                             user:user]
                              dictionaryValueUsingConfig:config]];
}

-(BOOL)shouldCreateDebugEventForContext:(LDEventTrackingContext*)eventTrackingContext lastEventResponseDate:(NSDate*)lastEventResponseDate {
    if (!eventTrackingContext || !eventTrackingContext.debugEventsUntilDate) { return NO; }
    if ([lastEventResponseDate isLaterThan:eventTrackingContext.debugEventsUntilDate]) { return NO; }
    if ([[NSDate date] isLaterThan:eventTrackingContext.debugEventsUntilDate]) { return NO; }

    return YES;
}

-(void)addEventDictionary:(NSDictionary*)eventDictionary {
    if (!eventDictionary || eventDictionary.allKeys.count == 0) {
        DEBUG_LOGX(@"LDDataManager addEventDictionary aborting. Event dictionary is missing or empty.");
        return;
    }
    dispatch_async(eventsQueue, ^{
        if([self isAtEventCapacity:self.eventsArray]) {
            DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@", eventDictionary[@"key"]);
            return;
        }
        [self.eventsArray addObject:eventDictionary];
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
    [self.eventsArray removeAllObjects];
}

- (NSMutableArray *)retrieveEventsArray {
    return [[NSMutableArray alloc] initWithArray:self.eventsArray];
}

@end

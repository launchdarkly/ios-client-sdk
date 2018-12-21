//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import "LDUserModel.h"
#import "LDEventModel.h"
#import "LDUtil.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigValue.h"
#import "LDEventTrackingContext.h"
#import "LDFlagConfigTracker.h"
#import "LDUserEnvironment.h"
#import "NSDate+ReferencedDate.h"
#import "NSDictionary+LaunchDarkly.h"
#import "NSThread+MainExecutable.h"
#import "LDConfig+LaunchDarkly.h"

int const kUserCacheSize = 5;
NSString * const kUserDefaultsKeyUserEnvironments = @"com.launchdarkly.dataManager.userEnvironments";

@interface LDDataManager()
@property (nonatomic, copy) NSString *mobileKey;
@property (nonatomic, strong) LDConfig *config;
@property (atomic, strong) NSMutableArray *eventsArray;
@property (nonatomic, strong) dispatch_queue_t eventsQueue;
@property (nonatomic, strong) dispatch_queue_t saveUserQueue;
@property (nonatomic, strong, readonly, class) NSUserDefaults *userSaveSyncKey;
@end

@implementation LDDataManager
+(instancetype)dataManagerWithMobileKey:(NSString*)mobileKey config:(LDConfig*)config {
    return [[LDDataManager alloc] initWithMobileKey:mobileKey config:config];
}

-(instancetype)initWithMobileKey:(NSString*)mobileKey config:(LDConfig*)config {
    if (mobileKey.length == 0 || config == nil) {
        return nil;
    }
    if (!(self = [super init])) {
        return nil;
    }
    
    self.mobileKey = mobileKey;
    self.config = config;
    self.eventsArray = [[NSMutableArray alloc] init];
    self.eventsQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.launchdarkly.eventQueue.%@", mobileKey] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.saveUserQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.launchdarkly.dataManager.saveUserQueue.%@", mobileKey] UTF8String], DISPATCH_QUEUE_SERIAL);

    return self;
}

#pragma mark - users

+(void)convertToEnvironmentBasedCacheForUser:(LDUserModel*)user config:(LDConfig*)config {
    if (user == nil || config == nil) {
        NSString *reason = @"";
        if (user == nil) {
            reason = [reason stringByAppendingString:@"user is missing."];
        }
        if (config == nil) {
            reason = [reason stringByAppendingString:[NSString stringWithFormat:@"%@config is missing.", reason.length > 0 ? @" " : @""]];
        }
        DEBUG_LOG(@"LDDataManager cannot convert to environment based cache. %@", reason);
        return;
    }
    @synchronized (LDDataManager.userSaveSyncKey) {
        // userEnvironments is a <userKey, LDUserEnvironment> dictionary - the new environment based store. Each entry contains all the mobile key feature flags for a single user.
        NSMutableDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [NSMutableDictionary dictionaryWithDictionary:[LDDataManager retrieveUserEnvironments]];
        LDUserEnvironment *userEnvironment = userEnvironments[user.key];
        DEBUG_LOG(@"LDDataManager found cached user environments for:%@",[userEnvironments.allKeys componentsJoinedByString:@", "]);
        // userModels is a <userKey, LDUserModel> dictionary - the old user store for a single environment
        NSMutableDictionary<NSString*, LDUserModel*> *userModels = [NSMutableDictionary dictionaryWithDictionary:[LDDataManager retrieveStoredUserModels]];
        LDUserModel *userModel = userModels[user.key];
        DEBUG_LOG(@"LDDataManager found cached user models for:%@",[userModels.allKeys componentsJoinedByString:@", "]);
        if (userEnvironment == nil) {
            //no environment based store for the user
            if (userModel == nil) {
                DEBUG_LOG(@"LDDataManager did not find cached user:%@. Nothing to convert.", user.key);
                return; //No stored userModel (old store), so there's nothing to convert
            }
            //There is an old user in the store, convert it by copying it into all the environments. We know that's not right for all but one, but since we don't know which this is the best we can do. As soon as the SDK gets responses from the server, these should all be replaced.
            NSMutableDictionary *usersInEnvironments = [NSMutableDictionary dictionaryWithCapacity:config.mobileKeys.count];
            for (NSString *mobileKey in config.mobileKeys) {
                usersInEnvironments[mobileKey] = [userModel copy];
            }
            userEnvironments[user.key] = [LDUserEnvironment userEnvironmentForUserWithKey:user.key environments:usersInEnvironments];
            [LDDataManager saveUserEnvironments:[userEnvironments copy]];
            DEBUG_LOG(@"LDDataManager converted cached user:%@ to environment-based cache.", user.key);
            return;
        }
        //Found a userEnvironment for this user, safe to delete the userModel store for this user
        if (userModel == nil) {
            DEBUG_LOG(@"LDDataManager found environment-based cache for user:%@. No cached user model found.", user.key);
            return; //No stored userModel, nothing to delete
        }
        [userModels removeObjectForKey:user.key];
        [LDDataManager storeUserModels:[userModels copy]];
        DEBUG_LOG(@"LDDataManager found environment-based cache for user:%@. Removed cached user model.", user.key);
    }
}

-(void)purgeOldUserEnvironment:(NSMutableDictionary<NSString*, LDUserEnvironment*> *)dictionary {
    if (dictionary == nil || dictionary.count < kUserCacheSize) {
        return;
    }
    NSArray *sortedKeys = [dictionary keysSortedByValueUsingComparator: ^(LDUserEnvironment *userEnvironment1, LDUserEnvironment *userEnvironment2) {
        //Oldest to Newest
        return [userEnvironment1.lastUpdated compare:userEnvironment2.lastUpdated];
    }];

    [dictionary removeObjectForKey:sortedKeys.firstObject];
}

#pragma mark save
+(NSUserDefaults*)userSaveSyncKey {
    return [NSUserDefaults standardUserDefaults];
}

-(void)saveUser:(LDUserModel*)user {
    [self saveEnvironmentForUser:user completion:nil];
}

-(void)saveEnvironmentForUser:(LDUserModel*)user completion:(void (^)(void))completion {
    if (user == nil) {
        DEBUG_LOGX(@"LDDataManager unable to save environment for user. User is missing.");
        if (completion != nil) {
            completion();
        }
        return;
    }
    LDUserModel *userCopy = [user copy];      //Preserve the user while waiting to save on the saveQueue
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.saveUserQueue, ^{
        @synchronized (LDDataManager.userSaveSyncKey) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            NSMutableDictionary<NSString*, LDUserEnvironment*> *storedUserEnvironments = [NSMutableDictionary dictionaryWithDictionary:[strongSelf retrieveUserEnvironments]];
            LDUserEnvironment *userEnvironment = storedUserEnvironments[userCopy.key];
            if (userEnvironment == nil) {
                //UserEnvironment wasn't found, create one
                userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:userCopy.key environments:nil];
                [self purgeOldUserEnvironment:storedUserEnvironments];
            }
            if (userEnvironment == nil) {
                //Couldn't find or create a UserEnvironment - bailout
                //This is totally defensive. The only way this would ever happen is if the system couldn't allocate memory to a new userEnvironment.
                DEBUG_LOG(@"LDDataManager unable to save user:%@ for mobileKey:%@", userCopy.key, strongSelf.mobileKey);
                if (completion != nil) {
                    completion();
                }
                return;
            }

            [userEnvironment setUser:userCopy mobileKey:strongSelf.mobileKey];
            storedUserEnvironments[userCopy.key] = userEnvironment;
            [strongSelf saveUserEnvironments:storedUserEnvironments];

            if (completion == nil) {
                return;
            }
            completion();
        }
    });
}

#pragma mark Find / Restore
-(LDUserModel*)findUserWithKey:(NSString*)key {
    return [self findEnvironmentForUserWithKey:key];
}

-(LDFlagConfigModel*)retrieveFlagConfigForUser:(LDUserModel*)user {
    if (user == nil) {
        return [[LDFlagConfigModel alloc] init];
    }
    LDUserModel *restoredUser = [self findUserWithKey:user.key];
    if (restoredUser == nil) {
        return user.flagConfig ?: [[LDFlagConfigModel alloc] init];
    }
    return restoredUser.flagConfig;
}

-(LDUserModel*)findEnvironmentForUserWithKey:(NSString*)userKey {
    if (userKey.length == 0) {
        DEBUG_LOGX(@"LDDataManager unable to find user. Key is missing or empty.");
        return nil;
    }
    NSDictionary<NSString*, LDUserEnvironment*> *storedUserEnvironments = [self retrieveUserEnvironments];
    LDUserEnvironment *storedUserEnvironment = storedUserEnvironments[userKey];
    return [storedUserEnvironment userForMobileKey:self.mobileKey];
}

#pragma mark UserEnvironment

-(void)saveUserEnvironments:(NSDictionary<NSString*, LDUserEnvironment*>*)userEnvironments {
    [LDDataManager saveUserEnvironments:userEnvironments];
}

+(void)saveUserEnvironments:(NSDictionary<NSString*, LDUserEnvironment*>*)userEnvironments {
    NSDictionary *userEnvironmentDictionaries = [userEnvironments compactMapUsingBlock:^id(id  _Nonnull originalValue) {
        if (![originalValue isKindOfClass:[LDUserEnvironment class]]) {
            return nil;
        }
        LDUserEnvironment *userEnvironment = originalValue;
        return [userEnvironment dictionaryValue];
    }];
    [[NSUserDefaults standardUserDefaults] setObject:userEnvironmentDictionaries forKey:kUserDefaultsKeyUserEnvironments];
}

-(NSDictionary<NSString*, LDUserEnvironment*>*)retrieveUserEnvironments {
    return [LDDataManager retrieveUserEnvironments];
}

+(NSDictionary<NSString*, LDUserEnvironment*>*)retrieveUserEnvironments {
    NSDictionary *userEnvironmentDictionaries = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsKeyUserEnvironments];
    return [userEnvironmentDictionaries compactMapUsingBlock:^id(id  _Nonnull originalValue) {
        if (![originalValue isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        NSDictionary *userEnvironmentDictionary = originalValue;
        return [[LDUserEnvironment alloc] initWithDictionary:userEnvironmentDictionary];
    }];
}

#pragma mark Deprecated
-(void)saveUser:(LDUserModel *)user asDict:(BOOL)asDict completion:(void (^)(void))completion {
    LDUserModel *userCopy = [user copy];      //Preserve the user while waiting to save on the saveQueue
    dispatch_async(self.saveUserQueue, ^{
        @synchronized (LDDataManager.userSaveSyncKey) {
            NSMutableDictionary * storedUserModels = [self retrieveStoredUserModels];
            if (storedUserModels) {
                LDUserModel * storedUser = storedUserModels[userCopy.key];
                if (storedUser != nil) {
                    // User is found
                    userCopy.updatedAt = [NSDate date];
                    storedUserModels[userCopy.key] = userCopy;
                } else {
                    // User is not found so need to create and purge old users
                    userCopy.updatedAt = [NSDate date];
                    storedUserModels[userCopy.key] = userCopy;
                }
            } else {
                // No Dictionary exists so create
                storedUserModels = [[NSMutableDictionary alloc] init];
                userCopy.updatedAt = [NSDate date];
                storedUserModels[userCopy.key] = userCopy;
            }
            storedUserModels[userCopy.key] = userCopy;
            if (asDict) {
                [self storeUserModels:storedUserModels];
            }
            else{
                [self deprecatedStoreUserDictionary:storedUserModels];
            }
            DEBUG_LOG(@"LDDataManager saved user:%@ %@", userCopy.key, userCopy);
            if (completion != nil) {
                [NSThread performOnMainThread:^{
                    completion();
                } waitUntilDone:NO];
            }
        }
    });
}

-(LDUserModel*)findUserModelWithKey:(NSString*)key {
    NSDictionary *storedUserModels = [self retrieveStoredUserModels];
    if (storedUserModels.count == 0) {
        return nil;
    }

    LDUserModel *foundUserModel = storedUserModels[key];
    if (foundUserModel == nil) {
        return nil;
    }

    DEBUG_LOG(@"LDDataManager found cached user:%@ %@", foundUserModel.key, foundUserModel);
    foundUserModel.updatedAt = [NSDate date];
    return foundUserModel;
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

-(void)storeUserModels:(NSDictionary *)userModels {
    [LDDataManager storeUserModels:userModels];
}

+(void)storeUserModels:(NSDictionary *)userModels {
    NSDictionary *userModelDictionaries = [userModels compactMapUsingBlock:^id(id originalValue) {
        if (originalValue == nil || ![originalValue isKindOfClass:[LDUserModel class]]) {
            return nil;
        }
        LDUserModel *user = originalValue;
        return [user dictionaryValueWithPrivateAttributesAndFlagConfig:YES];
    }];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userModelDictionaries forKey:kUserDictionaryStorageKey];
    [defaults synchronize];
}

-(nonnull NSMutableDictionary<NSString*,LDUserModel*>*)retrieveStoredUserModels {
    return [LDDataManager retrieveStoredUserModels];
}

+(nonnull NSMutableDictionary<NSString*,LDUserModel*>*)retrieveStoredUserModels {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *userModelDictionaries = [defaults objectForKey:kUserDictionaryStorageKey];
    NSMutableDictionary *userModels = [NSMutableDictionary dictionaryWithDictionary:[userModelDictionaries compactMapUsingBlock:^id(id originalValue) {
        if (originalValue == nil) {
            return nil;
        }
        if ([originalValue isKindOfClass:[NSData class]]) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:originalValue];
        }
        if ([originalValue isKindOfClass:[NSDictionary class]]) {
            return [[LDUserModel alloc] initWithDictionary:originalValue];
        }
        return nil;
    }]];
    return userModels;
}

#pragma mark Test Support
+(void)removeStoredUsers {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDefaultsKeyUserEnvironments];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDictionaryStorageKey];
}

#pragma mark - events

-(void)recordFlagEvaluationEventsWithFlagKey:(NSString*)flagKey
                           reportedFlagValue:(id)reportedFlagValue
                             flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                            defaultFlagValue:(id)defaultFlagValue
                                        user:(LDUserModel*)user {
    [self recordFeatureEventWithFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultFlagValue:defaultFlagValue user:user];
    [self recordDebugEventWithFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultFlagValue:defaultFlagValue user:user];
    [user.flagConfigTracker logRequestForFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultValue:defaultFlagValue];
}

-(void)recordFeatureEventWithFlagKey:(NSString*)flagKey
                   reportedFlagValue:(id)reportedFlagValue
                     flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                    defaultFlagValue:(id)defaultFlagValue
                                user:(LDUserModel*)user {
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
                                                         inlineUser:self.config.inlineUserInEvents]
                              dictionaryValueUsingConfig:self.config]];
}

-(void)recordCustomEventWithKey:(NSString *)eventKey customData:(NSDictionary *)customData user:(LDUserModel*)user {
    DEBUG_LOG(@"Creating custom event for custom key:%@ and customData:%@", eventKey, customData);
    [self addEventDictionary:[[LDEventModel customEventWithKey:eventKey customData:customData userValue:user inlineUser:self.config.inlineUserInEvents] dictionaryValueUsingConfig:self.config]];
}

-(void)recordIdentifyEventWithUser:(LDUserModel*)user {
    DEBUG_LOG(@"Creating identify event for user key:%@", user.key);
    [self addEventDictionary:[[LDEventModel identifyEventWithUser:user] dictionaryValueUsingConfig:self.config]];
}

-(void)recordSummaryEventAndResetTrackerForUser:(LDUserModel*)user {
    @synchronized (self) {
        LDFlagConfigTracker *trackerCopy = [user.flagConfigTracker copy];
        if (!trackerCopy.hasTrackedEvents) {
            DEBUG_LOGX(@"Tracker has no events to report. Discarding summary event.");
            return;
        }
        [user resetTracker];

        LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:trackerCopy];
        if (summaryEvent == nil) {
            DEBUG_LOGX(@"Failed to create summary event. Aborting.");
            return;
        }
        DEBUG_LOGX(@"Creating summary event");
        [self addEventDictionary:[summaryEvent dictionaryValueUsingConfig:self.config]];
    }
}

-(void)recordDebugEventWithFlagKey:(NSString *)flagKey
                 reportedFlagValue:(id)reportedFlagValue
                   flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                  defaultFlagValue:(id)defaultFlagValue
                              user:(LDUserModel*)user {
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
                              dictionaryValueUsingConfig:self.config]];
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
    dispatch_async(self.eventsQueue, ^{
        if([self isAtEventCapacity:self.eventsArray]) {
            DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@", eventDictionary[@"key"]);
            return;
        }
        [self.eventsArray addObject:eventDictionary];
    });
}

-(BOOL)isAtEventCapacity:(NSArray *)currentArray {
    return self.config.capacity && currentArray && [currentArray count] >= [self.config.capacity integerValue];
}

-(void) deleteProcessedEvents: (NSArray *) processedJsonArray {
    // Loop through processedEvents
    dispatch_async(self.eventsQueue, ^{
        NSInteger count = MIN([processedJsonArray count], [self.eventsArray count]);
        [self.eventsArray removeObjectsInRange:NSMakeRange(0, count)];
    });
}

-(void) allEventDictionaries:(void (^)(NSArray *))completion {
    dispatch_async(self.eventsQueue, ^{
        completion([NSArray arrayWithArray:self.eventsArray]);
    });
}

-(void)discardEventsDictionary {
    [self.eventsArray removeAllObjects];
}

@end

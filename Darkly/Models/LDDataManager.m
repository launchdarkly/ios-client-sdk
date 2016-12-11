//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import "LDEventModel.h"
#import "LDUtil.h"

int const kUserCacheSize = 5;

@interface LDDataManager()

@property (strong, nonatomic) NSMutableDictionary *eventDictionary;
@property (strong, nonatomic) dispatch_queue_t  eventsQueue;

@end

@implementation LDDataManager

+ (id)sharedManager {
    static LDDataManager *sharedDataManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataManager = [[self alloc] init];
        sharedDataManager.eventDictionary = [[NSMutableDictionary alloc] init];
        sharedDataManager.eventsQueue = dispatch_queue_create("com.launchdarkly.events", DISPATCH_QUEUE_SERIAL);
    });
    return sharedDataManager;
}

#pragma mark - users
-(void) purgeOldUser: (NSMutableDictionary *)dictionary {
    if (dictionary && [dictionary count] >= kUserCacheSize) {
        NSString *removalKey;
        NSDate *removalDate;
        for (id key in dictionary) {
            LDUserModel *currentUser = [dictionary objectForKey:key];
            if (currentUser) {
                if (removalKey) {
                    NSComparisonResult result = [removalDate compare:currentUser.updatedAt];
                    if (result==NSOrderedDescending) {
                        removalKey = currentUser.key;
                        removalDate = currentUser.updatedAt;
                    }
                } else {
                    removalKey = currentUser.key;
                    removalDate = currentUser.updatedAt;
                }
            } else {
                [dictionary removeObjectForKey:removalKey];
            }
        }
        [dictionary removeObjectForKey:removalKey];
    }
}

-(void) saveUser: (LDUserModel *) user {
    NSMutableDictionary *userDictionary = [self retrieveUserDictionary];
    if (userDictionary) {
        LDUserModel *resultUser = [userDictionary objectForKey:user.key];
        if (resultUser) {
            // User is found
            resultUser = user;
            resultUser.updatedAt = [NSDate date];
        } else {
            // User is not found so need to create and purge old users
            [self purgeOldUser: userDictionary];
            user.updatedAt = [NSDate date];
            [userDictionary setObject:user forKey:user.key];
        }
    } else {
        // No Dictionary exists so create
        userDictionary = [[NSMutableDictionary alloc] init];
        [userDictionary setObject:user forKey:user.key];
    }
    [userDictionary setObject:user forKey:user.key];
    [self storeUserDictionary:userDictionary];
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

- (void)storeUserDictionary:(NSDictionary *)userDictionary {
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
    NSMutableDictionary *retrievalDictionary = [[NSMutableDictionary alloc] init];
    NSDictionary *encodedDictionary = [defaults objectForKey:kUserDictionaryStorageKey];
    for (NSString *key in encodedDictionary) {
        LDUserModel *decodedUser = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[encodedDictionary objectForKey:key]];
        [retrievalDictionary setObject:decodedUser forKey:key];
    }
    return retrievalDictionary;
}

#pragma mark - events

-(void) createFeatureEvent: (NSString *)featureKey keyValue:(NSObject*)keyValue defaultKeyValue:(NSObject*)defaultKeyValue {
    if(![self isAtEventCapacity:_eventDictionary]) {
        DEBUG_LOG(@"Creating event for feature:%@ with value:%@ and fallback:%@", featureKey, keyValue, defaultKeyValue);
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.ldUser;
        LDEventModel *featureEvent = [[LDEventModel alloc] initFeatureEventWithKey: featureKey keyValue:keyValue defaultKeyValue:defaultKeyValue userValue:currentUser];
        
        if (!_eventDictionary) {
            // No Dictionary exists so create
            _eventDictionary = [[NSMutableDictionary alloc] init];
        }
        dispatch_async(_eventsQueue, ^{
            if ([_eventDictionary objectForKey:[NSString stringWithFormat:@"%ld", (long)featureEvent.creationDate]] != nil) {
                featureEvent.creationDate = featureEvent.creationDate + 1;
            }
            [_eventDictionary setObject:featureEvent forKey:[NSString stringWithFormat:@"%ld", (long)featureEvent.creationDate]];
        });
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding feature event %@", featureKey);
}

-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict {
    if(![self isAtEventCapacity:_eventDictionary]) {
        DEBUG_LOG(@"Creating event for custom key:%@ and value:%@", eventKey, customDict);
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.ldUser;
        LDEventModel *customEvent = [[LDEventModel alloc] initCustomEventWithKey: eventKey  andDataDictionary: customDict userValue:currentUser];
        
        if (!_eventDictionary) {
            // No Dictionary exists so create
            _eventDictionary = [[NSMutableDictionary alloc] init];
        }
        
        dispatch_async(_eventsQueue, ^{
            if ([_eventDictionary objectForKey:[NSString stringWithFormat:@"%ld", (long)customEvent.creationDate]] != nil) {
                customEvent.creationDate = customEvent.creationDate + 1;
            }
            [_eventDictionary setObject:customEvent forKey:[NSString stringWithFormat:@"%ld", (long)customEvent.creationDate]];
        });
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@ with dictionary %@", eventKey, customDict);
}

-(BOOL)isAtEventCapacity:(NSDictionary *)currentDictionary {
    LDConfig *ldConfig = [[LDClient sharedInstance] ldConfig];
    return ldConfig.capacity && currentDictionary && [NSNumber numberWithInteger:[currentDictionary count]] >= ldConfig.capacity;
}

-(void) deleteProcessedEvents: (NSArray *) processedJsonArray {
    // Loop through processedEvents
    for (NSDictionary *processedEventDict in processedJsonArray) {
        LDEventModel *processedEvent = [[LDEventModel alloc] initWithDictionary:processedEventDict];
        NSString *processedEventCreationDate = [NSString stringWithFormat:@"%ld", (long)processedEvent.creationDate];
        
        dispatch_async(_eventsQueue, ^{
            if ([_eventDictionary objectForKey:processedEventCreationDate]) {
                [_eventDictionary removeObjectForKey:processedEventCreationDate];
            }
        });
    }
}

-(NSArray *)allEventsDictionaryArray {
    NSMutableDictionary *dictionary = [self retrieveEventDictionary];
    if (dictionary && [dictionary count]) {
        NSMutableArray *eventArray = [[NSMutableArray alloc] init];
        for (NSString *key in dictionary) {
            LDEventModel *currentEvent = [dictionary objectForKey:key];
            [eventArray addObject:[currentEvent dictionaryValue]];
        }
        return eventArray;
    } else {
        return nil;
    }
}

-(NSArray*) allEventsJsonArray {
    NSArray *allEvents = [self allEventsDictionaryArray];
    if (allEvents && [allEvents count]) {
        return allEvents;
    } else {
        return nil;
    }
}

-(void)flushEventsDictionary {
    dispatch_async(_eventsQueue, ^{
        [_eventDictionary removeAllObjects];
    });
}

- (NSMutableDictionary *)retrieveEventDictionary {
    return [_eventDictionary mutableCopy];
}

@end

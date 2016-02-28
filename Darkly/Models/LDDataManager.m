//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import "LDEventModel.h"
#import "LDUtil.h"

int const kUserCacheSize = 5;

@implementation LDDataManager

+ (id)sharedManager {
    static LDDataManager *sharedDataManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataManager = [[self alloc] init];
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

-(void)storeEventDictionary:(NSDictionary *)eventDictionary {
    NSMutableDictionary *archiveDictionary = [[NSMutableDictionary alloc] init];
    for (NSString *key in eventDictionary) {
        NSData *eventEncodedObject = [NSKeyedArchiver archivedDataWithRootObject:(LDEventModel *)[eventDictionary objectForKey:key]];
        [archiveDictionary setObject:eventEncodedObject forKey:key];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:archiveDictionary forKey:kEventDictionaryStorageKey];
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

- (NSMutableDictionary *)retrieveEventDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *retrievalDictionary = [[NSMutableDictionary alloc] init];
    NSDictionary *encodedDictionary = [defaults objectForKey:kEventDictionaryStorageKey];
    for (NSString *key in encodedDictionary) {
        LDEventModel *decodedEvent = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[encodedDictionary objectForKey:key]];
        [retrievalDictionary setObject:decodedEvent forKey:key];
    }
    return retrievalDictionary;
}

-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    if(![self isAtEventCapacity:eventDictionary]) {
        DEBUG_LOG(@"Creating event for feature:%@ with value:%d and defaultValue:%d", featureKey, keyValue, defaultKeyValue);
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.ldUser;
        LDEventModel *featureEvent = [[LDEventModel alloc] initFeatureEventWithKey: featureKey keyValue:keyValue defaultKeyValue:defaultKeyValue userValue:currentUser];
        
        if (!eventDictionary) {
            // No Dictionary exists so create
            eventDictionary = [[NSMutableDictionary alloc] init];
        }
        [eventDictionary setObject:featureEvent forKey:[NSString stringWithFormat:@"%ld", (long)featureEvent.creationDate]];
        [self storeEventDictionary:eventDictionary];
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding feature event %@", featureKey);
}

-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    if(![self isAtEventCapacity:eventDictionary]) {
        DEBUG_LOG(@"Creating event for custom key:%@ and value:%@", eventKey, customDict);
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.ldUser;
        LDEventModel *customEvent = [[LDEventModel alloc] initCustomEventWithKey: eventKey  andDataDictionary: customDict userValue:currentUser];
        
        if (!eventDictionary) {
            // No Dictionary exists so create
            eventDictionary = [[NSMutableDictionary alloc] init];
        }
        [eventDictionary setObject:customEvent forKey:[NSString stringWithFormat:@"%ld", (long)customEvent.creationDate]];
        [self storeEventDictionary:eventDictionary];
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@ with dictionary %@", eventKey, customDict);
}

-(BOOL)isAtEventCapacity:(NSDictionary *)currentDictionary {
    LDConfig *ldConfig = [[LDClient sharedInstance] ldConfig];
    return ldConfig.capacity && currentDictionary && [NSNumber numberWithInteger:[currentDictionary count]] >= ldConfig.capacity;
}

-(void) deleteProcessedEvents: (NSArray *) processedJsonArray {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    // Loop through processedEvents
    for (NSDictionary *processedEventDict in processedJsonArray) {
        LDEventModel *processedEvent = [[LDEventModel alloc] initWithDictionary:processedEventDict];
        NSString *processedEventCreationDate = [NSString stringWithFormat:@"%ld", (long)processedEvent.creationDate];
        if ([eventDictionary objectForKey:processedEventCreationDate]) {
            [eventDictionary removeObjectForKey:processedEventCreationDate];
        }
    }
    [self storeEventDictionary:eventDictionary];
}

-(NSArray *)allEventsDictionaryArray {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    if (eventDictionary && [eventDictionary count]) {
        NSMutableArray *eventArray = [[NSMutableArray alloc] init];
        for (NSString *key in eventDictionary) {
            LDEventModel *currentEvent = [eventDictionary objectForKey:key];
            [eventArray addObject:[currentEvent dictionaryValue]];
        }
        return eventArray;
    } else {
        return nil;
    }
}

-(NSData*) allEventsJsonData {
    NSArray *allEvents = [self allEventsDictionaryArray];
    if (allEvents && [allEvents count]) {
        NSError *writeError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:allEvents options:NSJSONWritingPrettyPrinted error:&writeError];
        return jsonData;
    } else {
        return nil;
    }
}

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>
#import <BlocksKit/BlocksKit.h>
#import "LDEventModel.h"
#import "LDUtil.h"

int const kUserCacheSize = 5;

static NSString * const kUserDictionaryStorageKey = @"ldUserModelDictionary";
static NSString * const kEventDictionaryStorageKey = @"ldEventModelDictionary";

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
            if (!removalKey || removalDate>currentUser.updatedAt) {
                removalKey = currentUser.key;
                removalDate = currentUser.updatedAt;
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userDictionary forKey:kUserDictionaryStorageKey];
    [defaults synchronize];
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

- (NSMutableDictionary *)retrieveUserDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kUserDictionaryStorageKey];
    NSMutableDictionary *userDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return userDictionary;
}

#pragma mark - events

- (NSMutableDictionary *)retrieveEventDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *encodedObject = [defaults objectForKey:kEventDictionaryStorageKey];
    NSMutableDictionary *eventDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
    return eventDictionary;
}

-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    if(![self isAtEventCapacity:eventDictionary]) {
        DEBUG_LOG(@"Creating event for feature:%@ with value:%d and defaultValue:%d", featureKey, keyValue, defaultKeyValue);
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.user;
        LDEventModel *featureEvent = [[LDEventModel alloc] featureEventWithKey: featureKey keyValue:keyValue defaultKeyValue:defaultKeyValue userValue:currentUser];
        
        if (!eventDictionary) {
            // No Dictionary exists so create
            eventDictionary = [[NSMutableDictionary alloc] init];
        }
        [eventDictionary setObject:featureEvent forKey:[NSString stringWithFormat:@"%ld", (long)featureEvent.creationDate]];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:eventDictionary forKey:kEventDictionaryStorageKey];
        [defaults synchronize];
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding feature event %@", featureKey);
}

-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    if(![self isAtEventCapacity:eventDictionary]) {
        DEBUG_LOG(@"Creating event for custom key:%@ and value:%@", eventKey, customDict);
        LDClient *client = [LDClient sharedInstance];
        LDUserModel *currentUser = client.user;
        LDEventModel *customEvent = [[LDEventModel alloc] customEventWithKey: eventKey  andDataDictionary: customDict userValue:currentUser];
        
        if (!eventDictionary) {
            // No Dictionary exists so create
            eventDictionary = [[NSMutableDictionary alloc] init];
        }
        [eventDictionary setObject:customEvent forKey:[NSString stringWithFormat:@"%ld", (long)customEvent.creationDate]];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:eventDictionary forKey:kEventDictionaryStorageKey];
        [defaults synchronize];
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@ with dictionary %@", eventKey, customDict);
}

-(BOOL)isAtEventCapacity:(NSDictionary *)currentDictionary {
    LDConfig *ldConfig = [[LDClient sharedInstance] ldConfig];
    return ldConfig.capacity && currentDictionary && [NSNumber numberWithInteger:[currentDictionary count]] >= ldConfig.capacity;
}

-(void) deleteProcessedEvents: (NSArray *) processedJsonArray {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    // Loop through processedEvents
    for (NSDictionary *processedEventDict in processedJsonArray) {
        LDEventModel *processedEvent = [[LDEventModel alloc] initWithDictionary:processedEventDict];
        NSString *processedEventCreationDate = [NSString stringWithFormat:@"%ld", (long)processedEvent.creationDate];
        if ([eventDictionary objectForKey:processedEventCreationDate]) {
            [eventDictionary removeObjectForKey:processedEventCreationDate];
        }
    }
    [defaults setObject:eventDictionary forKey:kEventDictionaryStorageKey];
    [defaults synchronize];
}

-(NSArray *)allEvents {
    NSMutableDictionary *eventDictionary = [self retrieveEventDictionary];
    if (eventDictionary) {
        return [eventDictionary allValues];
    } else {
        return nil;
    }
}

-(NSData*) allEventsJsonData {
    NSArray *allEvents = [self allEvents];
    if (allEvents) {
        NSError *writeError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:allEvents options:NSJSONWritingPrettyPrinted error:&writeError];
        return jsonData;
    } else {
        return nil;
    }
}

@end

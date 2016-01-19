//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>
#import <BlocksKit/BlocksKit.h>
#import "LDEvent.h"
#import "LDUtil.h"

int const kUserCacheSize = 5;

static NSString * const kUserDictionaryStorageKey = @"ldUserModelDictionary";

@implementation LDDataManager
@synthesize eventCreatedCount;

+ (id)sharedManager {
    static LDDataManager *sharedDataManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataManager = [[self alloc] init];
        sharedDataManager.eventCreatedCount = [NSNumber numberWithInt: 0];
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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

-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    
    if(![self isAtEventCapacity]) {
        DEBUG_LOG(@"Creating event for feature:%@ with value:%d and defaultValue:%d", featureKey, keyValue, defaultKeyValue);
        LDEvent *featureEvent = [[LDEvent alloc] featureEventWithKey: featureKey keyValue:keyValue defaultKeyValue:defaultKeyValue];
        
        [self.managedObjectContext performBlockAndWait:^{
            [MTLManagedObjectAdapter managedObjectFromModel:featureEvent
                                       insertingIntoContext:self.managedObjectContext
                                                      error:nil];
            
            int eventCreatedCountInt = [eventCreatedCount intValue];
            eventCreatedCount = [NSNumber numberWithInt:eventCreatedCountInt + 1];
            [self saveContext];
        }];
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding feature event %@", featureKey);
}

-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict {
    if(![self isAtEventCapacity]) {
        DEBUG_LOG(@"Creating event for custom key:%@ and value:%@", eventKey, customDict);
        LDEvent *customEvent = [[LDEvent alloc] customEventWithKey: eventKey  andDataDictionary: customDict];
        
        [self.managedObjectContext performBlockAndWait:^{
            [MTLManagedObjectAdapter managedObjectFromModel:customEvent
                                       insertingIntoContext:self.managedObjectContext
                                                      error:nil];
            int eventCreatedCountInt = [eventCreatedCount intValue];
            eventCreatedCount = [NSNumber numberWithInt:eventCreatedCountInt + 1];
            [self saveContext];
        }];
    } else
        DEBUG_LOG(@"Events have surpassed capacity. Discarding event %@ with dictionary %@", eventKey, customDict);
}

-(BOOL)isAtEventCapacity {
    LDConfig *ldConfig = [[LDClient sharedInstance] ldConfig];
    
    return ldConfig.capacity && eventCreatedCount >= ldConfig.capacity;
}

-(NSManagedObject *)findEvent: (NSInteger) date {
    DEBUG_LOG(@"Retrieving event for date: %ld", (long)date);
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"EventEntity"
                                   inManagedObjectContext:self.managedObjectContext]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"creationDate == %ld", date];
    request.predicate = predicate;
    
    __block NSArray *eventMoArray = nil;
    [self.managedObjectContext performBlockAndWait:^{
        
        NSError *error = nil;
        eventMoArray = [self.managedObjectContext executeFetchRequest:request
                                                                  error:&error];
    }];
    
    if (eventMoArray.count > 0) {
        return eventMoArray.firstObject;
    }
    return nil;
}

-(void) deleteProcessedEvents: (NSArray *) processedJsonArray {
    __block BOOL hasMatchedEvents = NO;
    
    [self.managedObjectContext performBlockAndWait:^{
        // Loop through processedEvents
        for (NSDictionary *processedEventDict in processedJsonArray) {
            // Attempt to find match in currentEvents based on creationDate
            LDEvent *processedEvent = [MTLJSONAdapter modelOfClass:[LDEvent class]
                                                fromJSONDictionary:processedEventDict
                                                             error:nil];
            NSManagedObject *matchedCurrentEvent = [self findEvent: [processedEvent creationDate]];
            // If events match
            if (matchedCurrentEvent) {
                [self.managedObjectContext deleteObject:matchedCurrentEvent];
                hasMatchedEvents = YES;
                
                int eventCreatedCountInt = [eventCreatedCount intValue];
                eventCreatedCount = [NSNumber numberWithInt:eventCreatedCountInt - 1];
            }
        }
        // If number of managedObjects is greater than 0, then Save Context
        if (hasMatchedEvents) {
            [self saveContext];
        }
    }];    
}

-(NSArray *)allEvents {
    DEBUG_LOGX(@"Retrieving all events");
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"EventEntity"
                                   inManagedObjectContext:self.managedObjectContext]];
    
    __block NSMutableArray  *eventsArray = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        NSArray *eventMoArray = [self.managedObjectContext executeFetchRequest:request
                                                                           error:&error];
        eventsArray = @[].mutableCopy;
        
        for (int eventCount = 0; [eventMoArray count] > eventCount; eventCount++) {
            LDEvent *event = [MTLManagedObjectAdapter modelOfClass:[LDEvent class]
                                                 fromManagedObject: [eventMoArray objectAtIndex: eventCount]
                                                             error: nil];
            [eventsArray addObject: event];
        };
    }];
    return eventsArray;
}

-(NSData*) allEventsJsonData {
    NSError *error = nil;
    LDClient *client = [LDClient sharedInstance];
    LDUser *currentUser = client.user;
    
    NSArray *allEvents = [self allEvents];
    
    NSData *jsonData = nil;
    if (allEvents && allEvents.count>0) {
        NSMutableArray *eventJsonDictArray = [NSMutableArray array];
        
        for (int eventCount = 0; allEvents.count > eventCount; eventCount++) {
            LDEvent *event = [allEvents objectAtIndex: eventCount];
            
            NSMutableDictionary *eventsDictionary = [MTLJSONAdapter JSONDictionaryFromModel:event
                                                                                      error: nil].mutableCopy;
            NSDictionary *jSONDictionary = [MTLJSONAdapter JSONDictionaryFromModel:currentUser error: nil];
            [eventsDictionary setObject: jSONDictionary forKey: @"user"];
            [eventJsonDictArray addObject:eventsDictionary];
        }
        
        jsonData = [NSJSONSerialization dataWithJSONObject:eventJsonDictArray
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    }
    return jsonData;
}

@end

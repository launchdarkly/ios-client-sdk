//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDDataManager.h"
#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>
#import "LDEvent.h"
#import "LDUtil.h"

int const kUserCacheSize = 5;

@implementation LDDataManager
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;
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
-(void)purgeOldUsers {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"UserEntity"
                                   inManagedObjectContext:self.managedObjectContext]];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"updatedAt" ascending:YES];
    request.sortDescriptors = @[sortDescriptor];
    
    __block NSArray *userMoArray = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        userMoArray = [self.managedObjectContext executeFetchRequest:request
                                                                 error:&error];
        
        if (userMoArray.count >= kUserCacheSize) {
            int numToDelete = (int)userMoArray.count - (kUserCacheSize + 1);
            for (int userMOIndex = 0; userMOIndex < userMoArray.count; userMOIndex++) {
                if (userMOIndex < numToDelete) {
                    DEBUG_LOG(@"Deleting cached User at index: %d", userMOIndex);
                    [self.managedObjectContext deleteObject: [userMoArray objectAtIndex:userMOIndex]];
                }
            }
        }
        [self saveContext];
    }];
}

-(void) saveUser: (LDUser *) user {
    UserEntity *userEntity = [self findUserEntityWithkey:user.key];
    
    if (userEntity) {
        user.config = [MTLManagedObjectAdapter modelOfClass:[LDFlagConfig class] fromManagedObject: (NSManagedObject *)userEntity.config error: nil];
    } else {
        [self purgeOldUsers];
    }
    
    
    [self.managedObjectContext performBlockAndWait:^{
        [MTLManagedObjectAdapter managedObjectFromModel: user
                                   insertingIntoContext: self.managedObjectContext
                                                  error: nil];
        
        [self saveContext];
    }];
}


-(UserEntity *)findUserEntityWithkey:(NSString *)key {
    DEBUG_LOG(@"Retrieving user with key: %@", key);
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"UserEntity"
                                   inManagedObjectContext:self.managedObjectContext]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"key == %@", key];
    request.predicate = predicate;
    
    __block NSArray *userMoArray = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        userMoArray = [self.managedObjectContext executeFetchRequest:request
                                                               error:&error];
    }];
    
    if (userMoArray.count > 0) {
        return userMoArray.firstObject;
    }
    return nil;
}

-(LDUser *)findUserWithkey: (NSString *)key {
    NSManagedObject *userMo = [self findUserEntityWithkey:key];
    
    if (userMo) {
        NSError *error;
        LDUser *user = [MTLManagedObjectAdapter modelOfClass:[LDUser class] fromManagedObject:userMo error: &error];
        
        NSLog(@"Error is %@", [error debugDescription]);
        user.updatedAt = [NSDate date];
        return user;
    }
    return nil;
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

#pragma mark - Core Data stack

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    NSString *bundlePath = [[NSBundle bundleForClass:[LDClient class]] pathForResource:@"DarklyLibraryModels"  ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    
    NSString *modelPath = [bundle pathForResource:@"darkly" ofType:@"momd"];
    NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
    managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: self.managedObjectModel];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"darkly.sqlite"];
    NSError *error = nil;
    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:@"darkly" code:9999 userInfo:dict];
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    return persistentStoreCoordinator;
}


- (NSManagedObjectContext *)managedObjectContext {
    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [managedObjectContext setPersistentStoreCoordinator:coordinator];
    return managedObjectContext;
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    if (self.managedObjectContext != nil) {
        [self.managedObjectContext performBlock:^{
            NSError *error = nil;
            if (![self.managedObjectContext save:&error])
                NSLog(@"Error saving to child context %@, %@", error, [error userInfo]);
        }];
    }
}
@end

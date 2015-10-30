//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "DataManager.h"
#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>
#import <BlocksKit/BlocksKit.h>
#import "Event.h"
#import "DarklyUtil.h"

@implementation DataManager
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;

+ (id)sharedManager {
    static DataManager *sharedAPIManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAPIManager = [[self alloc] init];
    });
    return sharedAPIManager;
}

-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    DEBUG_LOG(@"Creating event for feature:%@ with value:%d and defaultValue:%d", featureKey, keyValue, defaultKeyValue);
    Event *featureEvent = [[Event alloc] featureEventWithKey: featureKey keyValue:keyValue defaultKeyValue:defaultKeyValue];
    [MTLManagedObjectAdapter managedObjectFromModel:featureEvent
                               insertingIntoContext:[self managedObjectContext]
                                              error:nil];
    [self saveContext];
}

-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict {
    DEBUG_LOG(@"Creating event for custom key:%@ and value:%@", eventKey, customDict);
    Event *customEvent = [[Event alloc] customEventWithKey: eventKey  andDataDictionary: customDict];
    
    [MTLManagedObjectAdapter managedObjectFromModel:customEvent
                               insertingIntoContext:[self managedObjectContext]
                                              error:nil];
    [self saveContext];
}

-(NSManagedObject *)findEvent: (NSInteger) date {
    DEBUG_LOG(@"Retrieving event for date: %ld", (long)date);
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"EventEntity"
                                   inManagedObjectContext:[self managedObjectContext]]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"creationDate == %ld", date];
    request.predicate = predicate;

    __block NSArray *eventMoArray = nil;
    [self.managedObjectContext performBlockAndWait:^{

    NSError *error = nil;
    eventMoArray = [[self managedObjectContext] executeFetchRequest:request
                                                                       error:&error];
    }];
    
    if (eventMoArray.count > 0) {
        return eventMoArray.firstObject;
    }
    return nil;
}

-(NSArray *)allEvents {
    DEBUG_LOGX(@"Retrieving all events");
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"EventEntity"
                                   inManagedObjectContext:[self managedObjectContext]]];
    
    __block NSMutableArray  *eventsArray = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        NSArray *eventMoArray = [[self managedObjectContext] executeFetchRequest:request
                                                                           error:&error];
        eventsArray = @[].mutableCopy;
        
        for (int eventCount = 0; [eventMoArray count] > eventCount; eventCount++) {
            Event *event = [MTLManagedObjectAdapter modelOfClass:[Event class]
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
    User *currentUser = client.user;
    
    NSArray *allEvents = [self allEvents];
    
    NSData *jsonData = nil;
    if (allEvents && allEvents.count>0) {
        NSMutableArray *eventJsonDictArray = [NSMutableArray array];
        
        for (int eventCount = 0; allEvents.count > eventCount; eventCount++) {
            Event *event = [allEvents objectAtIndex: eventCount];
            
            NSMutableDictionary *eventsDictionary = [MTLJSONAdapter JSONDictionaryFromModel:event
                                                                                      error: nil].mutableCopy;
            NSDictionary *jSONDictionary = currentUser.dictionaryValue;
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
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"DarklyLibraryModels"  ofType:@"bundle"];
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
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
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
    if ([self managedObjectContext] != nil)
        [self saveInBackground];
}

-(void)saveInBackground {
    NSManagedObjectContext *temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    temporaryContext.parentContext = [self managedObjectContext];

    [temporaryContext performBlockAndWait:^{
        NSError *error = nil;
        if (![temporaryContext save:&error])
            NSLog(@"Error saving to child context %@, %@", error, [error userInfo]);
    }];
}
@end

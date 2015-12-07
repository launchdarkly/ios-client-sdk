//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import <CoreData/CoreData.h>
#import "LDUser.h"
#import "UserEntity.h"

extern int const kUserCacheSize;

@interface LDDataManager : NSObject
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong,atomic) NSNumber *eventCreatedCount;

+(LDDataManager *)sharedManager;

-(NSManagedObjectContext *) managedObjectContext;
-(NSManagedObject *)findEvent: (NSInteger) date;
-(NSData*) allEventsJsonData;
-(NSArray *)allEvents;
-(UserEntity *)findUserEntityWithkey: (NSString *)key;
-(LDUser *)findUserWithkey: (NSString *)key;
-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue;
-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict;
-(void) purgeOldUsers;
-(void) saveUser: (LDUser *) user;
-(void) saveContext;
-(void) deleteProcessedEvents: (NSArray *) processedJsonArray;

@end

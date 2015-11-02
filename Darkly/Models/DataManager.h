//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import <CoreData/CoreData.h>
#import "User.h"
#import "UserEntity.h"

@interface DataManager : NSObject
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

-(void) saveContext;
-(NSManagedObjectContext *) managedObjectContext;

+(DataManager *)sharedManager;

-(NSManagedObject *)findEvent: (NSInteger) date;
-(NSData*) allEventsJsonData;
-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue;
-(void) createCustomEvent: (NSString *)eventKey
withCustomValuesDictionary: (NSDictionary *)customDict;
-(NSArray *)allEvents;
-(Config *) createConfigFromJsonDict: (NSDictionary *)jsonConfigDictionary;
-(UserEntity *)findUserEntityWithkey: (NSString *)key;
-(User *)findUserWithkey: (NSString *)key;
-(void)purgeOldUsers;
-(void)deleteOrphanedConfig;

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import <CoreData/CoreData.h>
#import "LDUserModel.h"

extern int const kUserCacheSize;

@interface LDDataManager : NSObject

+(LDDataManager *)sharedManager;

-(NSData*) allEventsJsonData;
-(NSArray *)allEventsDictionaryArray;
-(NSMutableDictionary *)retrieveUserDictionary;
-(NSMutableDictionary *)retrieveEventDictionary;
-(LDUserModel *)findUserWithkey: (NSString *)key;
-(void) createFeatureEvent: (NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue;
-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict;
-(void) purgeOldUser: (NSMutableDictionary *)dictionary;
-(void) saveUser: (LDUserModel *) user;
-(void) deleteProcessedEvents: (NSArray *) processedJsonArray;

@end

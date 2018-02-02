//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import <CoreData/CoreData.h>
#import "LDUserModel.h"

extern int const kUserCacheSize;

@interface LDDataManager : NSObject

+(LDDataManager *)sharedManager;

-(void) allEventDictionaries:(void (^)(NSArray *eventDictionaries))completion;
-(NSMutableDictionary *)retrieveUserDictionary;
-(NSMutableArray *)retrieveEventsArray;
-(LDUserModel *)findUserWithkey: (NSString *)key;
-(void) createFeatureEvent: (NSString *)featureKey keyValue:(NSObject*)keyValue defaultKeyValue:(NSObject*)defaultKeyValue user:(LDUserModel*)user config:(LDConfig*)config;
-(void) createCustomEvent: (NSString *)eventKey withCustomValuesDictionary: (NSDictionary *)customDict user:(LDUserModel*)user config:(LDConfig*)config;
-(void) purgeOldUser: (NSMutableDictionary *)dictionary;
-(void) saveUser: (LDUserModel *) user;
-(void) saveUserDeprecated:(LDUserModel *)user __deprecated_msg("Use saveUser: instead");
-(void) deleteProcessedEvents: (NSArray *) processedJsonArray;
-(void)flushEventsDictionary;

@end

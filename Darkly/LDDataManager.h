//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import <CoreData/CoreData.h>
#import "LDUserModel.h"

@class LDFlagConfigTracker;

extern int const kUserCacheSize;

@interface LDDataManager : NSObject

+(LDDataManager *)sharedManager;

-(void) allEventDictionaries:(void (^)(NSArray *eventDictionaries))completion;
-(NSMutableDictionary*)retrieveUserDictionary;
-(NSMutableArray*)retrieveEventsArray;
-(LDUserModel*)findUserWithkey: (NSString *)key;
-(void)createFeatureEventWithFlagKey:(NSString*)flagKey flagValue:(NSObject*)flagValue defaultFlagValue:(NSObject*)defaultFlagValue user:(LDUserModel*)user config:(LDConfig*)config;
-(void)createCustomEventWithKey:(NSString*)eventKey customData:(NSDictionary*)customData user:(LDUserModel*)user config:(LDConfig*)config;
-(void)createIdentifyEventWithUser:(LDUserModel*)user config:(LDConfig*)config;
-(void)createSummaryEventWithTracker:(LDFlagConfigTracker*)tracker config:(LDConfig*)config;
-(void)createDebugEventWithFlagKey:(NSString*)flagKey flagValue:(NSObject*)flagValue defaultFlagValue:(NSObject*)defaultFlagValue user:(LDUserModel*)user config:(LDConfig*)config;
-(void)purgeOldUser: (NSMutableDictionary *)dictionary;
-(void)saveUser: (LDUserModel *) user;
-(void)saveUserDeprecated:(LDUserModel *)user __deprecated_msg("Use saveUser: instead");
-(void)deleteProcessedEvents: (NSArray *) processedJsonArray;
-(void)flushEventsDictionary;

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDUserModel.h"

@class LDFlagConfigValue;
@class LDFlagConfigTracker;

extern int const kUserCacheSize;

@interface LDDataManager : NSObject

@property (nonatomic, strong) NSDate *lastEventResponseDate;

+(LDDataManager *)sharedManager;

-(void) allEventDictionaries:(void (^)(NSArray *eventDictionaries))completion;
-(NSMutableDictionary*)retrieveUserDictionary;
-(NSMutableArray*)retrieveEventsArray;
-(LDUserModel*)findUserWithkey: (NSString *)key;
-(void)createFlagEvaluationEventsWithFlagKey:(NSString*)flagKey
                           reportedFlagValue:(id)reportedFlagValue
                             flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                            defaultFlagValue:(id)defaultFlagValue
                                        user:(LDUserModel*)user
                                      config:(LDConfig*)config;
-(void)createFeatureEventWithFlagKey:(NSString*)flagKey
                   reportedFlagValue:(id)reportedFlagValue
                     flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                    defaultFlagValue:(id)defaultFlagValue
                                user:(LDUserModel*)user
                              config:(LDConfig*)config;
-(void)createCustomEventWithKey:(NSString*)eventKey customData:(NSDictionary*)customData user:(LDUserModel*)user config:(LDConfig*)config;
-(void)createIdentifyEventWithUser:(LDUserModel*)user config:(LDConfig*)config;
-(void)createSummaryEventWithTracker:(LDFlagConfigTracker*)tracker config:(LDConfig*)config;
-(void)createDebugEventWithFlagKey:(NSString *)flagKey
                 reportedFlagValue:(id)reportedFlagValue
                   flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                  defaultFlagValue:(id)defaultFlagValue
                              user:(LDUserModel*)user
                            config:(LDConfig*)config;
-(void)saveUser: (LDUserModel *) user;
-(void)saveUserDeprecated:(LDUserModel *)user __deprecated_msg("Use saveUser: instead");
-(void)deleteProcessedEvents: (NSArray *) processedJsonArray;
-(void)flushEventsDictionary;

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDConfig.h"

@class LDUserModel;
@class LDFlagConfigModel;
@class LDFlagConfigValue;
@class LDFlagConfigTracker;

@interface LDDataManager : NSObject
@property (nonnull, nonatomic, copy, readonly) NSString *mobileKey;
@property (nonnull, nonatomic, strong, readonly) LDConfig *config;
@property (nullable, nonatomic, strong) NSDate *lastEventResponseDate;

+(nullable instancetype)dataManagerWithMobileKey:(nonnull NSString*)mobileKey config:(nonnull LDConfig*)config;
-(nullable instancetype)initWithMobileKey:(nonnull NSString*)mobileKey config:(nonnull LDConfig*)config;

//User Store
+(void)convertToEnvironmentBasedCacheForUser:(LDUserModel*)user config:(LDConfig*)config;
-(void)saveUser:(nonnull LDUserModel*)user;
-(nullable LDUserModel*)findUserWithKey:(nonnull NSString*)key;
-(nullable LDFlagConfigModel*)retrieveFlagConfigForUser:(nonnull LDUserModel*)user;

//Events
-(void)allEventDictionaries:(void (^)(NSArray * _Nullable eventDictionaries))completion;
-(void)recordFlagEvaluationEventsWithFlagKey:(nonnull NSString*)flagKey
                           reportedFlagValue:(nonnull id)reportedFlagValue
                             flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                            defaultFlagValue:(nonnull id)defaultFlagValue
                                        user:(nonnull LDUserModel*)user;
-(void)recordFeatureEventWithFlagKey:(nonnull NSString*)flagKey
                   reportedFlagValue:(nonnull id)reportedFlagValue
                     flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                    defaultFlagValue:(nonnull id)defaultFlagValue
                                user:(nonnull LDUserModel*)user;
-(void)recordCustomEventWithKey:(nonnull NSString*)eventKey customData:(nullable NSDictionary*)customData user:(nonnull LDUserModel*)user;
-(void)recordIdentifyEventWithUser:(nonnull LDUserModel*)user;
-(void)recordSummaryEventWithTracker:(nullable LDFlagConfigTracker*)tracker;
-(void)recordDebugEventWithFlagKey:(nonnull NSString*)flagKey
                 reportedFlagValue:(nonnull id)reportedFlagValue
                   flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                  defaultFlagValue:(nonnull id)defaultFlagValue
                              user:(nonnull LDUserModel*)user;
-(void)deleteProcessedEvents:(nullable NSArray*)processedJsonArray;

@end

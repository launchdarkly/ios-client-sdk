//
//  LDEventModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDUserModel.h"
#import "NSDate+ReferencedDate.h"

@class LDConfig;
@class LDFlagConfigValue;
@class LDFlagConfigTracker;

@interface LDEventModel : NSObject <NSCoding>
//all event kinds
@property (nullable, nonatomic, strong) NSString *kind;

//feature, debug, custom, & identify events
@property (nullable, nonatomic, strong) NSString *key;
@property (nonatomic, assign) LDMillisecond creationDate;
@property (nullable, nonatomic, strong) LDUserModel *user;
@property (nonatomic, assign) BOOL inlineUser;

//feature & debug events only
@property (nullable, nonatomic, strong) LDFlagConfigValue *flagConfigValue;
@property (nullable, nonatomic, strong) id reportedValue;
@property (nullable, nonatomic, strong) id defaultValue;

//custom events only
@property (nullable, nonatomic, strong) NSDictionary *data;

//summary events only
@property (nonatomic, assign) LDMillisecond startDateMillis;
@property (nonatomic, assign) LDMillisecond endDateMillis;
@property (nullable, nonatomic, strong) NSDictionary *flagRequestSummary;

-(nonnull NSDictionary *)dictionaryValueUsingConfig:(nonnull LDConfig*)config;

+(nullable instancetype)featureEventWithFlagKey:(nonnull NSString *)flagKey
                              reportedFlagValue:(nonnull id)reportedFlagValue
                                flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                               defaultFlagValue:(nullable id)defaultflagValue
                                           user:(nonnull LDUserModel*)user
                                     inlineUser:(BOOL)inlineUser;
-(nullable instancetype)initFeatureEventWithFlagKey:(nonnull NSString *)flagKey
                                  reportedFlagValue:(nonnull id)reportedFlagValue
                                    flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                                   defaultFlagValue:(nullable id)defaultFlagValue
                                               user:(nonnull LDUserModel*)user
                                         inlineUser:(BOOL)inlineUser;

+(nullable instancetype)customEventWithKey:(nonnull NSString*)featureKey
                                customData:(nonnull NSDictionary*)customData
                                 userValue:(nonnull LDUserModel*)userValue
                                inlineUser:(BOOL)inlineUser;
-(nullable instancetype)initCustomEventWithKey:(nonnull NSString*)featureKey
                                    customData:(nonnull NSDictionary*)customData
                                     userValue:(nonnull LDUserModel*)userValue
                                    inlineUser:(BOOL)inlineUser;

+(nullable instancetype)identifyEventWithUser:(nonnull LDUserModel*)user;
-(nullable instancetype)initIdentifyEventWithUser:(nonnull LDUserModel*)user;

+(nullable instancetype)summaryEventWithTracker:(nonnull LDFlagConfigTracker*)tracker;
-(nullable instancetype)initSummaryEventWithTracker:(nonnull LDFlagConfigTracker*)tracker;

+(nullable instancetype)debugEventWithFlagKey:(nonnull NSString*)flagKey
                            reportedFlagValue:(nonnull id)reportedFlagValue
                              flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                             defaultFlagValue:(nullable id)defaultFlagValue
                                         user:(nonnull LDUserModel*)user;
-(nullable instancetype)initDebugEventWithFlagKey:(nonnull NSString*)flagKey
                                reportedFlagValue:(nonnull id)reportedFlagValue
                                  flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                                 defaultFlagValue:(nullable id)defaultFlagValue
                                             user:(nonnull LDUserModel*)user;

-(nonnull NSString*)description;
@end

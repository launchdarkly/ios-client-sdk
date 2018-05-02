//
//  LDEventModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDUserModel.h"

@class LDConfig;
@class LDFlagConfigValue;
@class LDFlagConfigTracker;

@interface LDEventModel : NSObject <NSCoding>
//all event kinds
@property (nullable, nonatomic, strong) NSString *kind;

//feature, debug, custom, & identify events
@property (nullable, nonatomic, strong) NSString *key;
@property (atomic, assign) NSInteger creationDate;
@property (nullable, nonatomic, strong) LDUserModel *user;
@property (nonatomic, assign) BOOL inlineUser;

//feature & debug events only
@property (nullable, nonatomic, strong) NSObject *value;
@property (nullable, nonatomic, strong) LDFlagConfigValue *flagConfigValue;
@property (nullable, nonatomic, strong) id defaultValue;

//custom events only
@property (nullable, nonatomic, strong) NSDictionary *data;

//summary events only
@property (nonatomic, assign) NSInteger startDateMillis;
@property (nonatomic, assign) NSInteger endDateMillis;
@property (nullable, nonatomic, strong) NSDictionary *flagRequestSummary;

-(nonnull id)initWithDictionary:(nonnull NSDictionary*)dictionary;
-(nonnull NSDictionary *)dictionaryValueUsingConfig:(nonnull LDConfig*)config;

+(nullable instancetype)featureEventWithFlagKey:(nonnull NSString *)flagKey
                                flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                               defaultFlagValue:(nullable NSObject*)defaultflagValue
                                           user:(nonnull LDUserModel*)user
                                     inlineUser:(BOOL)inlineUser;
-(nullable instancetype)initFeatureEventWithFlagKey:(nonnull NSString *)flagKey
                                    flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                                   defaultFlagValue:(nullable NSObject*)defaultFlagValue
                                               user:(nonnull LDUserModel*)user
                                         inlineUser:(BOOL)inlineUser;

+(nullable instancetype)featureEventWithFlagKey:(nonnull NSString *)flagKey
                                      flagValue:(nullable NSObject*)flagValue
                               defaultFlagValue:(nullable NSObject*)defaultflagValue
                                      userValue:(nonnull LDUserModel*)userValue
                                     inlineUser:(BOOL)inlineUser;
-(nullable instancetype)initFeatureEventWithFlagKey:(nonnull NSString *)flagKey
                                          flagValue:(nullable NSObject*)flagValue
                                   defaultFlagValue:(nullable NSObject*)defaultFlagValue
                                          userValue:(nonnull LDUserModel*)userValue
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
                     flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                    defaultFlagValue:(nullable id)defaultFlagValue
                                user:(nonnull LDUserModel*)user;
-(nullable instancetype)initDebugEventWithFlagKey:(nonnull NSString*)flagKey
                         flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                        defaultFlagValue:(nullable id)defaultFlagValue
                                    user:(nonnull LDUserModel*)user;

+(nullable instancetype)debugEventWithFlagKey:(nonnull NSString *)flagKey
                                    flagValue:(nullable NSObject*)flagValue
                             defaultFlagValue:(nullable NSObject*)defaultflagValue
                                    userValue:(nonnull LDUserModel*)userValue;
-(nullable instancetype)initDebugEventWithFlagKey:(nonnull NSString *)flagKey
                                        flagValue:(nullable NSObject*)flagValue
                                 defaultFlagValue:(nullable NSObject*)defaultFlagValue
                                        userValue:(nonnull LDUserModel*)userValue;

-(nonnull NSString*)description;
@end

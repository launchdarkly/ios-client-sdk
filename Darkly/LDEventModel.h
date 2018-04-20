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
@property (nonnull, nonatomic, strong) NSObject *value;
@property (nonnull, nonatomic, strong) NSObject *defaultValue;

//custom events only
@property (nullable, nonatomic, strong) NSDictionary *data;

//summary events only
@property (nonatomic, assign) NSInteger startDateMillis;
@property (nonatomic, assign) NSInteger endDateMillis;
@property (nonatomic, strong, nullable) NSDictionary *flagRequestSummary;

-(nonnull id)initWithDictionary:(nonnull NSDictionary*)dictionary;
-(nonnull NSDictionary *)dictionaryValueUsingConfig:(nonnull LDConfig*)config;

+(nullable instancetype)featureEventWithFlagKey:(nonnull NSString *)flagKey
                                      flagValue:(nullable NSObject*)flagValue
                               defaultFlagValue:(nullable NSObject*)defaultflagValue
                                      userValue:(nonnull LDUserModel *)userValue
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

+(nullable instancetype)debugEventWithFlagKey:(nonnull NSString *)flagKey
                                    flagValue:(nullable NSObject*)flagValue
                             defaultFlagValue:(nullable NSObject*)defaultflagValue
                                    userValue:(nonnull LDUserModel *)userValue;
-(nullable instancetype)initDebugEventWithFlagKey:(nonnull NSString *)flagKey
                                        flagValue:(nullable NSObject*)flagValue
                                 defaultFlagValue:(nullable NSObject*)defaultFlagValue
                                        userValue:(nonnull LDUserModel*)userValue;
@end

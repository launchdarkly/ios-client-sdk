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

@interface LDEventModel : NSObject <NSCoding>
@property (nullable, nonatomic, strong) NSString *key;
@property (nullable, nonatomic, strong) NSString *kind;
@property (atomic, assign) NSInteger creationDate;
@property (nullable, nonatomic, strong) NSDictionary *data;
@property (nullable, nonatomic, strong) LDUserModel *user;
@property (nonatomic, assign) BOOL inlineUser;

@property (nonnull, nonatomic, strong) NSObject *value;
@property (nonnull, nonatomic, strong) NSObject *defaultValue;

-(nonnull id)initWithDictionary:(nonnull NSDictionary*)dictionary;
-(nonnull NSDictionary *)dictionaryValueUsingConfig:(nonnull LDConfig*)config;

+(nullable instancetype)featureEventWithFlagKey:(nonnull NSString *)flagKey
                                      flagValue:(NSObject* _Nullable)flagValue
                               defaultFlagValue:(NSObject* _Nullable)defaultflagValue
                                      userValue:(nonnull LDUserModel *)userValue
                                     inlineUser:(BOOL)inlineUser;

-(nullable instancetype)initFeatureEventWithFlagKey:(nonnull NSString *)flagKey
                                          flagValue:(NSObject* _Nullable)flagValue
                                   defaultFlagValue:(NSObject* _Nullable)defaultFlagValue
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

@end

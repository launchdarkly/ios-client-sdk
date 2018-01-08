//
//  LDUserModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDConfig.h"

@class LDFlagConfigModel;

extern NSString * __nonnull const kUserPropertyNameIp;
extern NSString * __nonnull const kUserPropertyNameCountry;
extern NSString * __nonnull const kUserPropertyNameName;
extern NSString * __nonnull const kUserPropertyNameFirstName;
extern NSString * __nonnull const kUserPropertyNameLastName;
extern NSString * __nonnull const kUserPropertyNameEmail;
extern NSString * __nonnull const kUserPropertyNameAvatar;
extern NSString * __nonnull const kUserPropertyNameCustom;
extern NSString * __nonnull const kUserPropertyNameDevice;
extern NSString * __nonnull const kUserPropertyNameOs;

@interface LDUserModel : NSObject <NSCoding>
@property (nullable, nonatomic, strong, setter=key:) NSString *key;
@property (nullable, nonatomic, strong) NSString *ip;
@property (nullable, nonatomic, strong) NSString *country;
@property (nullable, nonatomic, strong) NSString *name;
@property (nullable, nonatomic, strong) NSString *firstName;
@property (nullable, nonatomic, strong) NSString *lastName;
@property (nullable, nonatomic, strong) NSString *email;
@property (nullable, nonatomic, strong) NSString *avatar;
@property (nullable, nonatomic, strong) NSDictionary *custom;
@property (nullable, nonatomic, strong) NSDate *updatedAt;
@property (nullable, nonatomic, strong) LDFlagConfigModel *config;

@property (nonatomic, assign) BOOL anonymous;
@property (nullable, nonatomic, strong) NSString *device;
@property (nullable, nonatomic, strong) NSString *os;

-(nonnull id)initWithDictionary:(nonnull NSDictionary *)dictionary;
-(nonnull NSString *) convertToJson;
-(nonnull NSDictionary *)dictionaryValue;
-(nonnull NSDictionary *)dictionaryValueWithConfig:(BOOL)includeConfig;
-(nonnull NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateProperties:(BOOL)includePrivate privateProperties:(nullable NSArray<NSString *> *)privateProperties;

-(NSObject * __nonnull) flagValue: ( NSString * __nonnull )keyName;
-(BOOL) doesFlagExist: (nonnull NSString *)keyName;

+(NSArray<NSString *> * __nonnull) allUserPropertyNames;

@end

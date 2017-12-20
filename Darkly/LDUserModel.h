//
//  LDUserModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagConfigModel;

static NSString * __nonnull const kUserPropertyNameIp;
static NSString * __nonnull const kUserPropertyNameCountry;
static NSString * __nonnull const kUserPropertyNameName;
static NSString * __nonnull const kUserPropertyNameFirstName;
static NSString * __nonnull const kUserPropertyNameLastName;
static NSString * __nonnull const kUserPropertyNameEmail;
static NSString * __nonnull const kUserPropertyNameAvatar;
static NSString * __nonnull const kUserPropertyNameCustom;
static NSString * __nonnull const kUserPropertyNameDevice;
static NSString * __nonnull const kUserPropertyNameOs;

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
-(nonnull NSDictionary *)dictionaryValueWithConfig:(BOOL)withConfig;

-(NSObject * __nonnull) flagValue: ( NSString * __nonnull )keyName;
-(BOOL) doesFlagExist: (nonnull NSString *)keyName;

+(NSSet<NSString *> * __nonnull) allUserPropertyNames;

@end

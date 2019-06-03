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
@class LDFlagConfigTracker;

extern NSString * __nonnull const kUserAttributeIp;
extern NSString * __nonnull const kUserAttributeCountry;
extern NSString * __nonnull const kUserAttributeName;
extern NSString * __nonnull const kUserAttributeFirstName;
extern NSString * __nonnull const kUserAttributeLastName;
extern NSString * __nonnull const kUserAttributeEmail;
extern NSString * __nonnull const kUserAttributeAvatar;
extern NSString * __nonnull const kUserAttributeCustom;

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
@property (nullable, nonatomic, strong) LDFlagConfigModel *flagConfig;
@property (nullable, nonatomic, strong, readonly) LDFlagConfigTracker *flagConfigTracker;
@property (nonatomic, strong, nullable) NSArray<NSString *>* privateAttributes;

@property (nonatomic, assign) BOOL anonymous;
@property (nullable, nonatomic, strong) NSString *device;
@property (nullable, nonatomic, strong) NSString *os;

-(nonnull id)initWithDictionary:(nonnull NSDictionary *)dictionary;
-(nonnull NSDictionary *)dictionaryValueWithPrivateAttributesAndFlagConfig:(BOOL)includeFlags;
-(nonnull NSDictionary *)dictionaryValueWithFlagConfig:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate config:(nullable LDConfig*)config;

+(NSArray<NSString *> * __nonnull) allUserAttributes;

-(void)resetTracker;

-(nonnull instancetype)copy;

@end

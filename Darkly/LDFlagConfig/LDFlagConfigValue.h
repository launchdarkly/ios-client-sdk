//
//  LDFlagConfigValue.h
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDEventTrackingContext;

extern NSString * _Nonnull const kLDFlagConfigValueKeyValue;
extern NSString * _Nonnull const kLDFlagConfigValueKeyVersion;
extern NSString * _Nonnull const kLDFlagConfigValueKeyFlagVersion;
extern NSString * _Nonnull const kLDFlagConfigValueKeyVariation;

extern NSInteger const kLDFlagConfigValueItemDoesNotExist;

@interface LDFlagConfigValue: NSObject
//Core Items
@property (nullable, nonatomic, strong) id value;
@property (nonatomic, assign) NSInteger modelVersion;
@property (nonatomic, assign) NSInteger variation;
//Optional Items, excluded from equality tests
@property (nullable, nonatomic, strong) NSNumber *flagVersion;
@property (nullable, nonatomic, strong) LDEventTrackingContext *eventTrackingContext;

+(nullable instancetype)flagConfigValueWithObject:(nullable id)object;
-(nullable instancetype)initWithObject:(nullable id)object;

-(void)encodeWithCoder:(nonnull NSCoder*)encoder;
-(nullable id)initWithCoder:(nonnull NSCoder*)decoder;
-(nonnull NSDictionary*)dictionaryValue;
-(nonnull NSDictionary*)dictionaryValueUseFlagVersionForVersion:(BOOL)useFlagVersion includeEventTrackingContext:(BOOL)includeEventTrackingContext;

///Returns true when the core items of both flagConfigValues are the same.
///Ignores the optional items
-(BOOL)isEqualToFlagConfigValue:(nullable LDFlagConfigValue*)other;
-(BOOL)isEqual:(nullable id)object;
///Returns true when the dictionary has the same core item values as the flagConfigValue
///NOTE: Will return false if the dictionary was created with UseFlagVersionForVersion = YES and the flagVersion differs from the modelVersion
-(BOOL)hasPropertiesMatchingDictionary:(nullable NSDictionary*)dictionary;

-(nonnull NSString*)description;
@end

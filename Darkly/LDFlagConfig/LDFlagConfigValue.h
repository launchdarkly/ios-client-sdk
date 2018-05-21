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
extern NSString * _Nonnull const kLDFlagConfigValueKeyVariation;

extern NSInteger const kLDFlagConfigValueItemDoesNotExist;

@interface LDFlagConfigValue: NSObject
@property (nullable, nonatomic, strong) id value;
@property (nonatomic, assign) NSInteger flagConfigModelVersion;
@property (nonatomic, assign) NSInteger flagConfigValueVersion;
@property (nonatomic, assign) NSInteger variation;
@property (nullable, nonatomic, strong) LDEventTrackingContext *eventTrackingContext;

+(nullable instancetype)flagConfigValueWithObject:(nullable id)object;
-(nullable instancetype)initWithObject:(nullable id)object;

-(void)encodeWithCoder:(nonnull NSCoder*)encoder;
-(nullable id)initWithCoder:(nonnull NSCoder*)decoder;
-(nonnull NSDictionary*)dictionaryValue;

-(BOOL)isEqualToFlagConfigValue:(nullable LDFlagConfigValue*)other;
-(BOOL)isEqual:(nullable id)object;
-(BOOL)hasPropertiesMatchingDictionary:(nullable NSDictionary*)dictionary;

-(nonnull NSString*)description;
@end

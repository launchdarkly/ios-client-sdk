//
//  LDFlagConfigValue.h
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * _Nonnull const kLDFlagConfigValueKeyValue;
extern NSString * _Nonnull const kLDFlagConfigValueKeyVersion;
extern NSString * _Nonnull const kLDFlagConfigValueKeyVariation;

extern NSInteger const kLDFlagConfigVersionDoesNotExist;
extern NSInteger const kLDFlagConfigVariationDoesNotExist;

@interface LDFlagConfigValue: NSObject
@property (nonatomic, strong, nullable) id value;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, assign) NSInteger variation;

+(nullable instancetype)flagConfigValueWithObject:(nullable id)object;
-(nullable instancetype)initWithObject:(nullable id)object;

-(void)encodeWithCoder:(nonnull NSCoder*)encoder;
-(nullable id)initWithCoder:(nonnull NSCoder*)decoder;
-(nonnull NSDictionary*)dictionaryValue;

-(BOOL)isEqual:(nullable id)object;
-(BOOL)hasPropertiesMatchingDictionary:(nullable NSDictionary*)dictionary;

-(nonnull NSString*)description;
@end

//
//  LDFlagConfigValue+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDFlagConfigValue.h"

extern const NSInteger kLDFlagConfigVariationDoesNotExist;
extern NSString * const kLDFlagConfigValueKeyEventTrackingContext;

extern NSString * const kLDFlagKeyIsABool;
extern NSString * const kLDFlagKeyIsANumber;
extern NSString * const kLDFlagKeyIsADouble;
extern NSString * const kLDFlagKeyIsAString;
extern NSString * const kLDFlagKeyIsAnArray;
extern NSString * const kLDFlagKeyIsADictionary;
extern NSString * const kLDFlagKeyIsANull;

extern NSString * const kLDFlagConfigValueKeyValue;
extern NSString * const kLDFlagConfigValueKeyVersion;
extern NSString * const kLDFlagConfigValueKeyVariation;

@interface LDFlagConfigValue(Testable)
+(NSDictionary*)flagConfigJsonObjectFromFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext;
+(instancetype)flagConfigValueFromJsonFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext;
+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey withVersions:(BOOL)withVersions eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext;
+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey;
+(NSArray<NSString*>*)fixtureFileNamesForFlagKey:(NSString*)flagKey includeVersion:(BOOL)includeVersion;
+(id)defaultValueForFlagKey:(NSString*)flagKey;
+(NSArray<NSString*>*)flagKeys;
+(NSDictionary<NSString*, NSArray<LDFlagConfigValue*>*>*)flagConfigValues;
-(NSDictionary*)dictionaryValueIncludeContext:(BOOL)includeContext;
@end

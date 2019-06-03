//
//  LDFlagConfigModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigModel.h"

@class LDEventTrackingContext;
@class LDEvent;

extern NSString * const kLDFlagConfigModelKeyKey;

@interface LDFlagConfigModel(Testable)

+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName;
+(instancetype)flagConfigWithOnlyFlagValuesFromJsonFileNamed:(NSString *)fileName;
+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key;
+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext;
+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext omitKey:(NSString*)key;
+(instancetype)stub;
+(instancetype)stubWithAlternateValuesForFlagKeys:(NSArray<NSString*>*)flagKeys;
+(instancetype)stubOmittingFlagKeys:(NSArray<NSString*>*)flagKeys;

+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version;
+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key;
-(LDFlagConfigModel*)applySSEEvent:(LDEvent*)event;
+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version;
+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key;
-(void)setFlagConfigValue:(LDFlagConfigValue*)flagConfigValue forKey:(NSString*)flagKey;
-(BOOL)isEmpty;
@end

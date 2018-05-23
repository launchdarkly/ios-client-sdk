//
//  LDFlagConfigValue+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigValue+Testable.h"
#import "NSJSONSerialization+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"

NSString * const kLDFlagKeyIsABool = @"isABool";
NSString * const kLDFlagKeyIsANumber = @"isANumber";
NSString * const kLDFlagKeyIsADouble = @"isADouble";
NSString * const kLDFlagKeyIsAString = @"isAString";
NSString * const kLDFlagKeyIsAnArray = @"isAnArray";
NSString * const kLDFlagKeyIsADictionary = @"isADictionary";
NSString * const kLDFlagKeyIsANull = @"isANull";

@implementation LDFlagConfigValue(Testable)
+(NSDictionary*)flagConfigJsonObjectFromFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext {
    NSMutableDictionary *flagConfigStub = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
    if (eventTrackingContext) {
        if (flagKey.length > 0) {
            NSMutableDictionary *flagConfigObject = [NSMutableDictionary dictionaryWithDictionary:flagConfigStub[flagKey]];
            [flagConfigObject addEntriesFromDictionary:[eventTrackingContext dictionaryValue]];
            flagConfigStub[flagKey] = [flagConfigObject copy];
        } else {
            [flagConfigStub addEntriesFromDictionary:[eventTrackingContext dictionaryValue]];
        }
    }

    return [flagConfigStub copy];
}

+(instancetype)flagConfigValueFromJsonFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext {
    id flagConfigStub = [LDFlagConfigValue flagConfigJsonObjectFromFileNamed:fileName flagKey:flagKey eventTrackingContext:eventTrackingContext];
    LDFlagConfigValue *flagConfigValue = flagKey.length > 0 ? [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[flagKey]]
        : [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub];
    return flagConfigValue;
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey {
    return [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey eventTrackingContext:[LDEventTrackingContext stub] includeFlagVersion:YES];
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext {
    return [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey eventTrackingContext:eventTrackingContext includeFlagVersion:YES];
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey includeFlagVersion:(BOOL)includeFlagVersion {
    return [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey eventTrackingContext:[LDEventTrackingContext stub] includeFlagVersion:includeFlagVersion];
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext includeFlagVersion:(BOOL)includeFlagVersion {
    NSMutableArray<LDFlagConfigValue*> *flagConfigValueStubs = [NSMutableArray array];

    for (NSString *fixtureName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey]) {
        LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureName flagKey:flagKey eventTrackingContext:eventTrackingContext];
        flagConfigValue.flagVersion = includeFlagVersion ? flagConfigValue.flagVersion : nil;
        [flagConfigValueStubs addObject:flagConfigValue];
    }
    
    return [NSArray arrayWithArray:flagConfigValueStubs];
}

+(NSArray<NSString*>*)fixtureFileNamesForFlagKey:(NSString*)flagKey {
    if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
        return @[@"boolConfigIsABool-false", @"boolConfigIsABool-true"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANumber]) {
        return @[@"numberConfigIsANumber-1", @"numberConfigIsANumber-2"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADouble]) {
        return @[@"doubleConfigIsADouble-Pi", @"doubleConfigIsADouble-e"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAString]) {
        return @[@"stringConfigIsAString-someString", @"stringConfigIsAString-someStringA"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAnArray]) {
        return @[@"arrayConfigIsAnArray-Empty", @"arrayConfigIsAnArray-1", @"arrayConfigIsAnArray-123"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADictionary]) {
        return @[@"dictionaryConfigIsADictionary-Empty", @"dictionaryConfigIsADictionary-3Key", @"dictionaryConfigIsADictionary-KeyA"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANull]) {
        return @[@"nullConfigIsANull-null"];
    }

    return @[];
}

+(id)defaultValueForFlagKey:(NSString*)flagKey {
    if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
        return @(YES);
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANumber]) {
        return @(7);
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADouble]) {
        return @(10.27);
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAString]) {
        return @"Jupiter II";
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAnArray]) {
        return @[@(1),@(2),@(3),@(4),@(5),@(6),@(7)];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADictionary]) {
        return @{@"default-dictionary-key": @"default-dictionary-value"};
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANull]) {
        return [NSNull null];
    }
    return @(YES);
}

+(id)differentValueForFlagKey:(NSString*)flagKey {
    if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
        return @(NO);
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANumber]) {
        return @(8);
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADouble]) {
        return @(170.1);
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAString]) {
        return @"Gallifrey";
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAnArray]) {
        return @[@(1),@(2),@(3)];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADictionary]) {
        return @{@"alternate-dictionary-key": @"alternate-dictionary-value"};
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANull]) {
        return [NSNull null];
    }
    return @(YES);
}

+(NSArray<NSString*>*)flagKeys {
    return @[kLDFlagKeyIsABool, kLDFlagKeyIsANumber, kLDFlagKeyIsADouble, kLDFlagKeyIsAString, kLDFlagKeyIsAnArray, kLDFlagKeyIsADictionary, kLDFlagKeyIsANull];
}

+(NSDictionary<NSString*, NSArray<LDFlagConfigValue*>*>*)flagConfigValues {
    NSMutableDictionary *flagConfigValues = [NSMutableDictionary dictionaryWithCapacity:[[LDFlagConfigValue flagKeys] count]];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        flagConfigValues[flagKey] = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
    }
    return [flagConfigValues copy];
}

-(NSDictionary*)dictionaryValueIncludeContext:(BOOL)includeContext {
    NSMutableDictionary *dictionaryValue = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryValue]];
    if (includeContext) {
        [dictionaryValue addEntriesFromDictionary:[self.eventTrackingContext dictionaryValue]];
    }

    return [dictionaryValue copy];
}
@end

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
    return [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey withVersions:YES eventTrackingContext:[LDEventTrackingContext stub]];
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey withVersions:(BOOL)withVersions eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext {
    NSMutableArray<LDFlagConfigValue*> *flagConfigValueStubs = [NSMutableArray array];

    for (NSString *fixtureName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:withVersions]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureName flagKey:flagKey eventTrackingContext:eventTrackingContext]];
    }
    
    return [NSArray arrayWithArray:flagConfigValueStubs];
}

+(NSArray<NSString*>*)fixtureFileNamesForFlagKey:(NSString*)flagKey includeVersion:(BOOL)includeVersion {
    if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
        return includeVersion ? @[@"boolConfigIsABool-false-withVersion", @"boolConfigIsABool-true-withVersion"]
            : @[@"boolConfigIsABool-false-withoutVersion", @"boolConfigIsABool-true-withoutVersion"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANumber]) {
        return includeVersion ? @[@"numberConfigIsANumber-1-withVersion", @"numberConfigIsANumber-2-withVersion"] :
            @[@"numberConfigIsANumber-1-withoutVersion", @"numberConfigIsANumber-2-withoutVersion"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADouble]) {
        return includeVersion ? @[@"doubleConfigIsADouble-Pi-withVersion", @"doubleConfigIsADouble-e-withVersion"] :
            @[@"doubleConfigIsADouble-Pi-withoutVersion", @"doubleConfigIsADouble-e-withoutVersion"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAString]) {
        return includeVersion ? @[@"stringConfigIsAString-someString-withVersion", @"stringConfigIsAString-someStringA-withVersion"] :
            @[@"stringConfigIsAString-someString-withoutVersion", @"stringConfigIsAString-someStringA-withoutVersion"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAnArray]) {
        return includeVersion ? @[@"arrayConfigIsAnArray-Empty-withVersion", @"arrayConfigIsAnArray-1-withVersion", @"arrayConfigIsAnArray-123-withVersion"] :
            @[@"arrayConfigIsAnArray-Empty-withoutVersion", @"arrayConfigIsAnArray-1-withoutVersion", @"arrayConfigIsAnArray-123-withoutVersion"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADictionary]) {
        return includeVersion ? @[@"dictionaryConfigIsADictionary-Empty-withVersion",
                                  @"dictionaryConfigIsADictionary-3Key-withVersion",
                                  @"dictionaryConfigIsADictionary-KeyA-withVersion"]
                                :
                                  @[@"dictionaryConfigIsADictionary-Empty-withoutVersion",
                                  @"dictionaryConfigIsADictionary-3Key-withoutVersion",
                                  @"dictionaryConfigIsADictionary-KeyA-withoutVersion"];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANull]) {
        return includeVersion ? @[@"nullConfigIsANull-null-withVersion"] :
            @[@"nullConfigIsANull-null-withoutVersion"];
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

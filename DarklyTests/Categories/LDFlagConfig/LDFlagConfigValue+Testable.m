//
//  LDFlagConfigValue+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigValue+Testable.h"
#import "NSJSONSerialization+Testable.h"

NSString * const kLDFlagKeyIsABool = @"isABool";
NSString * const kLDFlagKeyIsANumber = @"isANumber";
NSString * const kLDFlagKeyIsADouble = @"isADouble";
NSString * const kLDFlagKeyIsAString = @"isAString";
NSString * const kLDFlagKeyIsAnArray = @"isAnArray";
NSString * const kLDFlagKeyIsADictionary = @"isADictionary";
NSString * const kLDFlagKeyIsANull = @"isANull";

@implementation LDFlagConfigValue(Testable)
+(instancetype)flagConfigValueFromJsonFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:fileName];
    LDFlagConfigValue *flagConfigValue = flagKey.length > 0 ? [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[flagKey]] : [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub];
    flagConfigValue.variation = flagConfigValue.version;    //TODO: remove this when adding server support for variation
    return flagConfigValue;
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey {
    return [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey withVersions:YES];
}

+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey withVersions:(BOOL)withVersions {
    NSMutableArray<LDFlagConfigValue*> *flagConfigValueStubs = [NSMutableArray array];
    if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-false-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:flagKey]];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANumber]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"numberConfigIsANumber-1-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"numberConfigIsANumber-2-withVersion" flagKey:flagKey]];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADouble]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"doubleConfigIsADouble-Pi-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"doubleConfigIsADouble-e-withVersion" flagKey:flagKey]];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAString]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"stringConfigIsAString-someString-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"stringConfigIsAString-someStringA-withVersion" flagKey:flagKey]];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsAnArray]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"arrayConfigIsAnArray-Empty-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"arrayConfigIsAnArray-1-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"arrayConfigIsAnArray-123-withVersion" flagKey:flagKey]];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsADictionary]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"dictionaryConfigIsADictionary-Empty-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key-withVersion" flagKey:flagKey]];
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyA-withVersion" flagKey:flagKey]];
    }
    if ([flagKey isEqualToString:kLDFlagKeyIsANull]) {
        [flagConfigValueStubs addObject:[LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"nullConfigIsANull-null-withVersion" flagKey:flagKey]];
    }

    if (!withVersions) {
        for (LDFlagConfigValue* flagConfigValueStub in flagConfigValueStubs) {
            flagConfigValueStub.version = kLDFlagConfigVersionDoesNotExist;
            flagConfigValueStub.variation = kLDFlagConfigVariationDoesNotExist;
        }
    }
    
    return [NSArray arrayWithArray:flagConfigValueStubs];
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

@end

//
//  LDFlagCounter+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagCounter+Testable.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDFlagValueCounter+Testable.h"

extern NSString * const kLDFlagCounterKeyDefaultValue;
extern NSString * const kLDFlagCounterKeyCounters;

@implementation LDFlagCounter(Testable)
@dynamic flagValueCounters;

+(instancetype)stubForFlagKey:(NSString*)flagKey {
    return [[self class] stubForFlagKey:flagKey useKnownValues:YES];
}

+(instancetype)stubForFlagKey:(NSString*)flagKey useKnownValues:(BOOL)useKnownValues {
    return [LDFlagCounter stubForFlagKey:flagKey useKnownValues:useKnownValues includeFlagVersion:YES];
}

+(instancetype)stubForFlagKey:(NSString*)flagKey includeFlagVersion:(BOOL)includeFlagVersion {
    return [LDFlagCounter stubForFlagKey:flagKey useKnownValues:YES includeFlagVersion:includeFlagVersion];
}

+(instancetype)stubForFlagKey:(NSString*)flagKey useKnownValues:(BOOL)useKnownValues includeFlagVersion:(BOOL)includeFlagVersion {
    id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagCounter *flagCounter = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:defaultValue];

    if (useKnownValues) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey includeFlagVersion:includeFlagVersion];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            for (NSInteger logRequests = 0; logRequests < flagConfigValue.modelVersion; logRequests += 1 ) {
                [flagCounter logRequestWithFlagConfigValue:flagConfigValue reportedFlagValue:flagConfigValue.value defaultValue:defaultValue];
            }
        }
    } else {
        for (NSInteger logRequests = 0; logRequests < 3; logRequests += 1 ) {
            [flagCounter logRequestWithFlagConfigValue:nil reportedFlagValue:defaultValue defaultValue:defaultValue];
        }
    }

    return flagCounter;
}
@end

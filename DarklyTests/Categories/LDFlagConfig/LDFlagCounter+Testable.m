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
    id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagCounter *flagCounter = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:defaultValue];

    if (useKnownValues) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            for (NSInteger logRequests = 0; logRequests < flagConfigValue.modelVersion; logRequests += 1 ) {
                [flagCounter logRequestWithFlagConfigValue:useKnownValues ? flagConfigValue : nil defaultValue:defaultValue];
            }
        }
    } else {
        for (NSInteger logRequests = 0; logRequests < 3; logRequests += 1 ) {
            [flagCounter logRequestWithFlagConfigValue:nil defaultValue:defaultValue];
        }
    }

    return flagCounter;
}
@end

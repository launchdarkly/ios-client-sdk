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
            for (NSInteger logRequests = 0; logRequests < flagConfigValue.version; logRequests += 1 ) {
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

-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary {
    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];

    if (![self.defaultValue isEqual:dictionary[kLDFlagCounterKeyDefaultValue]]) {
        [mismatchedProperties addObject:kLDFlagCounterKeyDefaultValue];
    }

    if (!dictionary[kLDFlagCounterKeyCounters]) {
        [mismatchedProperties addObject:kLDFlagCounterKeyCounters];
    } else {
        NSArray<NSDictionary*> *countersFromDictionary = dictionary[kLDFlagCounterKeyCounters];
        for (NSDictionary *counterFromDictionary in countersFromDictionary) {
            BOOL isKnownValue = ![counterFromDictionary[kLDFlagValueCounterKeyUnknown] boolValue];
            LDFlagConfigValue *flagConfigValue = nil;
            if (isKnownValue) {
                flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:counterFromDictionary];
            }
            NSInteger variation = isKnownValue ? [counterFromDictionary[kLDFlagValueCounterKeyVersion] integerValue] : kLDFlagConfigVariationDoesNotExist;
            LDFlagValueCounter *flagValueCounter = [self valueCounterForFlagConfigValue:flagConfigValue];
            if (!flagValueCounter) {
                [mismatchedProperties addObject:[NSString stringWithFormat:@"variation_%ld", (long)variation]];
            } else {
                if (![flagValueCounter hasPropertiesMatchingDictionary:counterFromDictionary]) {
                    [mismatchedProperties addObject:[NSString stringWithFormat:@"variation_%ld", (long)variation]];
                }
            }
        }
    }

    if (mismatchedProperties.count > 0) {
        NSLog(@"[%@ %@] flag key %@ has unequal properties %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self.flagKey, [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }
    return YES;
}
@end

//
//  LDFlagConfigTracker+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigTracker+Testable.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDFlagCounter+Testable.h"
#import "NSDate+ReferencedDate.h"

extern NSString * const kEventModelKeyFeatures;
const NSTimeInterval kLDFlagConfigTrackerTrackingInterval = -30.0;

@implementation LDFlagConfigTracker(Testable)
@dynamic startDateMillis;
@dynamic mutableFlagCounters;

+(instancetype)stubTracker {
    NSDate *startStubbing = [NSDate date];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    tracker.startDateMillis = [[startStubbing dateByAddingTimeInterval:kLDFlagConfigTrackerTrackingInterval] millisSince1970];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        tracker.mutableFlagCounters[flagKey] = [LDFlagCounter stubForFlagKey:flagKey];
    }

    return tracker;
}

-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary {
    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];

    for (NSString *flagKey in self.mutableFlagCounters.allKeys) {
        LDFlagCounter *flagCounter = self.mutableFlagCounters[flagKey];
        NSDictionary *flagCounterDictionary = dictionary[flagKey];
        if (![flagCounter hasPropertiesMatchingDictionary:flagCounterDictionary]) {
            [mismatchedProperties addObject:[NSString stringWithFormat:@"%@-%@", kEventModelKeyFeatures, flagKey]];
        }
    }

    if (mismatchedProperties.count > 0) {
        NSLog(@"[%@ %@] has unequal properties %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }
    return YES;
}
@end

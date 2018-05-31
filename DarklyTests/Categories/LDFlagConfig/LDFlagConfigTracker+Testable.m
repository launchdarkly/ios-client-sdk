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
#import "LDEventTrackingContext+Testable.h"

extern NSString * const kEventModelKeyFeatures;
const NSTimeInterval kLDFlagConfigTrackerTrackingInterval = -30.0;

@implementation LDFlagConfigTracker(Testable)
@dynamic startDateMillis;
@dynamic mutableFlagCounters;

+(instancetype)stubTracker {
    return [LDFlagConfigTracker stubTrackerIncludeFlagVersion:YES];
}

+(instancetype)stubTrackerIncludeFlagVersion:(BOOL)includeFlagVersion {
    NSDate *startStubbing = [NSDate date];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    tracker.startDateMillis = [[startStubbing dateByAddingTimeInterval:kLDFlagConfigTrackerTrackingInterval] millisSince1970];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        tracker.mutableFlagCounters[flagKey] = [LDFlagCounter stubForFlagKey:flagKey includeFlagVersion:includeFlagVersion];
    }

    return tracker;
}

+(instancetype)stubTrackerUseKnownValues:(BOOL)useKnownValues {
    NSDate *startStubbing = [NSDate date];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    tracker.startDateMillis = [[startStubbing dateByAddingTimeInterval:kLDFlagConfigTrackerTrackingInterval] millisSince1970];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        tracker.mutableFlagCounters[flagKey] = [LDFlagCounter stubForFlagKey:flagKey useKnownValues:useKnownValues];
    }

    return tracker;
}

+(instancetype)stubTrackerWithNullValuesInFlagConfigValue {
    NSDate *startStubbing = [NSDate date];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    tracker.startDateMillis = [[startStubbing dateByAddingTimeInterval:kLDFlagConfigTrackerTrackingInterval] millisSince1970];
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"nullConfigIsANull-null" flagKey:kLDFlagKeyIsANull eventTrackingContext:eventTrackingContext];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        [tracker logRequestForFlagKey:flagKey reportedFlagValue:defaultValue flagConfigValue:flagConfigValue defaultValue:defaultValue];
        [tracker logRequestForFlagKey:flagKey reportedFlagValue:defaultValue flagConfigValue:flagConfigValue defaultValue:defaultValue];
        [tracker logRequestForFlagKey:flagKey reportedFlagValue:defaultValue flagConfigValue:flagConfigValue defaultValue:defaultValue];
    }
    return tracker;
}

@end

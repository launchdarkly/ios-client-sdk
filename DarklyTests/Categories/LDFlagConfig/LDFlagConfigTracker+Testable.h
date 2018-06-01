//
//  LDFlagConfigTracker+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigTracker.h"
#import "NSDate+ReferencedDate.h"

@interface LDFlagConfigTracker(Testable)
@property (nonatomic, assign) LDMillisecond startDateMillis;
@property (nonatomic, strong) NSMutableDictionary<NSString*, LDFlagCounter*> *mutableFlagCounters;
+(instancetype)stubTracker;
+(instancetype)stubTrackerIncludeFlagVersion:(BOOL)includeFlagVersion;
+(instancetype)stubTrackerUseKnownValues:(BOOL)useKnownValues;
+(instancetype)stubTrackerWithNullValuesInFlagConfigValue;
@end

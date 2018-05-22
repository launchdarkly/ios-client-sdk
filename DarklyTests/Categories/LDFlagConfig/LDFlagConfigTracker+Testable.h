//
//  LDFlagConfigTracker+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigTracker.h"

@interface LDFlagConfigTracker(Testable)
@property (nonatomic, assign) NSInteger startDateMillis;
@property (nonatomic, strong) NSMutableDictionary<NSString*, LDFlagCounter*> *mutableFlagCounters;
+(instancetype)stubTracker;
@end

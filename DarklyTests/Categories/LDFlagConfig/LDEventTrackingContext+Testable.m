//
//  LDEventTrackingContext+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 5/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventTrackingContext+Testable.h"

@implementation LDEventTrackingContext(Testable)
+(instancetype)contextWithTrackEvents:(BOOL)trackEvents debugEventsUntilDate:(NSDate*)debugEventsUntilDate {
    return nil;
}

-(instancetype)initWithTrackEvents:(BOOL)trackEvents debugEventsUntilDate:(NSDate*)debugEventsUntilDate {
    return nil;
}

-(BOOL)isEqualToContext:(LDEventTrackingContext*)otherContext {
    return NO;
}

-(BOOL)isEqual:(id)other {
    return NO;
}

@end

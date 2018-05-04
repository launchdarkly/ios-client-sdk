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
    return [[LDEventTrackingContext alloc] initWithTrackEvents:trackEvents debugEventsUntilDate:debugEventsUntilDate];
}

-(instancetype)initWithTrackEvents:(BOOL)trackEvents debugEventsUntilDate:(NSDate*)debugEventsUntilDate {
    if (!(self = [super init])) { return nil; }

    self.trackEvents = trackEvents;
    self.debugEventsUntilDate = debugEventsUntilDate;

    return self;
}

-(BOOL)isEqualToContext:(LDEventTrackingContext*)otherContext {
    return self.trackEvents == otherContext.trackEvents
    && ((!self.debugEventsUntilDate && !otherContext.debugEventsUntilDate) || ([self.debugEventsUntilDate isEqualToDate:otherContext.debugEventsUntilDate]));
}

-(BOOL)isEqual:(id)other {
    if (!other) { return NO; }
    if (![other isKindOfClass:[LDEventTrackingContext class]]) { return NO; }
    if (self == other) { return YES; }
    return [self isEqualToContext:other];
}

@end

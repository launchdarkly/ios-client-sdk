//
//  LDEventTrackingContext+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 5/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventTrackingContext+Testable.h"
#import "NSDate+ReferencedDate.h"
#import "NSNumber+LaunchDarkly.h"

@implementation LDEventTrackingContext(Testable)
+(instancetype)stub {
    return [LDEventTrackingContext contextWithTrackEvents:YES debugEventsUntilDate:[NSDate dateWithTimeIntervalSinceNow:30.0]];
}

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
        && ((!self.debugEventsUntilDate && !otherContext.debugEventsUntilDate) || ([self.debugEventsUntilDate isWithinTimeInterval:1.0 ofDate:otherContext.debugEventsUntilDate]));
}

-(BOOL)isEqual:(id)other {
    if (!other) { return NO; }
    if (![other isKindOfClass:[LDEventTrackingContext class]]) { return NO; }
    if (self == other) { return YES; }
    return [self isEqualToContext:other];
}

-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary {
    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];

    if (self.trackEvents) {
        if (!dictionary[kLDEventTrackingContextKeyTrackEvents] || (dictionary[kLDEventTrackingContextKeyTrackEvents] && ![dictionary[kLDEventTrackingContextKeyTrackEvents] boolValue])) {
            [mismatchedProperties addObject:kLDEventTrackingContextKeyTrackEvents];
        }
    } else {
        if (dictionary[kLDEventTrackingContextKeyTrackEvents] && [dictionary[kLDEventTrackingContextKeyTrackEvents] boolValue]) {
            [mismatchedProperties addObject:kLDEventTrackingContextKeyTrackEvents];
        }
    }

    if (self.debugEventsUntilDate) {
        if (dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]) {
            NSDate *otherDebugUntil = [NSDate dateFromMillisSince1970:[dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] ldMillisecondValue]];
            if (![self.debugEventsUntilDate isWithinTimeInterval:1.0 ofDate:otherDebugUntil]) {
                [mismatchedProperties addObject:kLDEventTrackingContextKeyDebugEventsUntilDate];
            }
        } else {
            [mismatchedProperties addObject:kLDEventTrackingContextKeyDebugEventsUntilDate];
        }
    } else {
        if (dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]) {
            [mismatchedProperties addObject:kLDEventTrackingContextKeyDebugEventsUntilDate];
        }
    }

    if (mismatchedProperties.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }
    return YES;
}
@end

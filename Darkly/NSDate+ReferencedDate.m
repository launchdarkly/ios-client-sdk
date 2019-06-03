//
//  NSDate+ReferencedDate.m
//  Darkly
//
//  Created by Mark Pokorny on 4/11/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSDate+ReferencedDate.h"

@implementation NSDate (ReferencedDate)
+(NSDate*)dateFromMillisSince1970:(LDMillisecond)millis {
    return [NSDate dateWithTimeIntervalSince1970:millis / 1000];
}

-(LDMillisecond)millisSince1970 {
    return (LDMillisecond)floor([self timeIntervalSince1970] * 1000);
}

-(BOOL)isWithinTimeInterval:(NSTimeInterval)timeInterval ofDate:(NSDate*)otherDate {
    if (!otherDate) { return NO; }
    if (timeInterval < 0.0) { return NO; }
    NSTimeInterval difference = fabs([self timeIntervalSinceDate:otherDate]);
    return difference <= timeInterval;
}

-(BOOL)isEarlierThan:(NSDate*)otherDate {
    if (!otherDate) { return NO; }
    return [self compare:otherDate] == NSOrderedAscending;
}

-(BOOL)isLaterThan:(NSDate*)otherDate {
    if (!otherDate) { return NO; }
    return [self compare:otherDate] == NSOrderedDescending;
}
@end

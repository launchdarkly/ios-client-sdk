//
//  LDFlagValueCounter.m
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagValueCounter.h"
#import "LDFlagConfigValue.h"

NSString * const kLDFlagValueCounterKeyFlagConfigValue = @"flagConfigValue";
NSString * const kLDFlagValueCounterKeyValue = @"value";
NSString * const kLDFlagValueCounterKeyVersion = @"version";
NSString * const kLDFlagValueCounterKeyVariation = @"variation";
NSString * const kLDFlagValueCounterKeyCount = @"count";
NSString * const kLDFlagValueCounterKeyUnknown = @"unknown";

@interface LDFlagValueCounter()
@property (nullable, nonatomic, strong) LDFlagConfigValue *flagConfigValue;
@property (nonatomic, assign, getter=isKnown) BOOL known;
@end

@implementation LDFlagValueCounter
+(instancetype)counterWithFlagConfigValue:(LDFlagConfigValue*)flagConfigValue reportedFlagValue:(id)reportedFlagValue {
    return [[LDFlagValueCounter alloc] initWithFlagConfigValue:flagConfigValue reportedFlagValue:reportedFlagValue];
}

-(instancetype)initWithFlagConfigValue:(LDFlagConfigValue*)flagConfigValue reportedFlagValue:(id)reportedFlagValue {
    if (!(self = [super init])) { return nil; }
    if (reportedFlagValue == nil) {
        reportedFlagValue = [NSNull null];
    }

    self.flagConfigValue = flagConfigValue;
    self.reportedFlagValue = reportedFlagValue;
    self.known = self.flagConfigValue != nil;
    self.count = 1;

    return self;
}

-(NSDictionary*)dictionaryValue {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:3];

    if (self.known) {
        if (self.flagConfigValue) {
            [dictionary addEntriesFromDictionary:[self.flagConfigValue dictionaryValueUseFlagVersionForVersion:YES includeEventTrackingContext:NO]];
        }
    } else {
        dictionary[kLDFlagValueCounterKeyUnknown] = @(YES);
    }
    dictionary[kLDFlagValueCounterKeyValue] = self.reportedFlagValue;
    dictionary[kLDFlagValueCounterKeyCount] = @(self.count);

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagValueCounter: %p, reportedFlagValue: %@, flagConfigValue: %@, count: %ld, known: %@>",
            self, [self.reportedFlagValue description], [self.flagConfigValue description], (long)self.count, self.known ? @"YES" : @"NO"];
}

-(id)copyWithZone:(NSZone*)zone {
    LDFlagValueCounter *copy = [[self class] new];
    copy.flagConfigValue = [self.flagConfigValue copy];
    copy.reportedFlagValue = [self.reportedFlagValue copy];
    copy.known = self.known;
    copy.count = self.count;

    return copy;
}

@end

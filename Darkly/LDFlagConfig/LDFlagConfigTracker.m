//
//  LDFlagConfigTracker.m
//  Darkly
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagConfigTracker.h"
#import "LDFlagCounter.h"
#import "LDFlagConfigValue.h"
#import "NSDate+ReferencedDate.h"
#import "LDUtil.h"

@interface LDFlagConfigTracker()
@property (nonatomic, assign) LDMillisecond startDateMillis;
@property (nonatomic, strong) NSMutableDictionary<NSString*, LDFlagCounter*> *mutableFlagCounters;
@end

@implementation LDFlagConfigTracker

+(instancetype)tracker {
    return [[LDFlagConfigTracker alloc] init];
}

-(instancetype)init {
    if (!(self = [super init])) { return nil; }

    @synchronized(self) {
        self.startDateMillis = [[NSDate date] millisSince1970];
        self.mutableFlagCounters = [NSMutableDictionary dictionary];

        return self;
    }
}

-(BOOL)hasTrackedEvents {
    @synchronized(self) {
        return self.mutableFlagCounters.count > 0;
    }
}

-(void)logRequestForFlagKey:(NSString*)flagKey reportedFlagValue:(id)reportedFlagValue flagConfigValue:(LDFlagConfigValue*)flagConfigValue defaultValue:(id)defaultValue {
    if(flagKey.length == 0) {
        DEBUG_LOGX(@"-[LDFlagConfigTracker logRequestForFlagKey:reportedFlagValue:flagConfigValue:defaultValue] called with an empty flagKey. Aborting.");
        return;
    }
    @synchronized(self) {
        if (!self.mutableFlagCounters[flagKey]) {
            self.mutableFlagCounters[flagKey] = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:defaultValue];
        }

        [self.mutableFlagCounters[flagKey] logRequestWithFlagConfigValue:flagConfigValue reportedFlagValue:reportedFlagValue];
    }
}

-(NSDictionary<NSString*, NSDictionary*>*)flagRequestSummary {
    @synchronized(self) {
        NSMutableDictionary *flagRequestSummary = [NSMutableDictionary dictionaryWithCapacity:self.mutableFlagCounters.count];
        NSDictionary<NSString*, LDFlagCounter*> *flagCounters = [NSDictionary dictionaryWithDictionary:self.mutableFlagCounters];
        for (NSString *flagKey in flagCounters.allKeys) {
            NSDictionary *counterDictionary = [flagCounters[flagKey] dictionaryValue];
            if (counterDictionary == nil) { continue; }
            flagRequestSummary[flagKey] = counterDictionary;
        }
        return [NSDictionary dictionaryWithDictionary:flagRequestSummary];
    }
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagConfigTracker: %p, flagCounters: %@, startDateMillis: %ld>", self, [self.mutableFlagCounters description], (long)self.startDateMillis];
}
@end

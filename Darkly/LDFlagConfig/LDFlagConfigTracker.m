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

@interface LDFlagConfigTracker()
@property (nonatomic, assign) NSInteger startDateMillis;
@property (nonatomic, strong) NSMutableDictionary<NSString*, LDFlagCounter*> *mutableFlagCounters;
@end

@implementation LDFlagConfigTracker

+(instancetype)tracker {
    return [[LDFlagConfigTracker alloc] init];
}

-(instancetype)init {
    if (!(self = [super init])) { return nil; }

    self.startDateMillis = [[NSDate date] millisSince1970];
    self.mutableFlagCounters = [NSMutableDictionary dictionary];

    return self;
}

-(NSDictionary*)flagCounters {
    return [NSDictionary dictionaryWithDictionary:self.mutableFlagCounters];
}

-(void)logRequestForFlagKey:(NSString*)flagKey flagConfigValue:(LDFlagConfigValue*)flagConfigValue defaultValue:(id)defaultValue {
    if (!self.mutableFlagCounters[flagKey]) {
        self.mutableFlagCounters[flagKey] = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:defaultValue];
    }
    
    id reportedValue = flagConfigValue ? flagConfigValue.value : defaultValue;
    NSInteger reportedVersion = flagConfigValue ? flagConfigValue.version : kLDFlagConfigVersionDoesNotExist;
    NSInteger reportedVariation = flagConfigValue ? flagConfigValue.variation : kLDFlagConfigVariationDoesNotExist;
    [self.mutableFlagCounters[flagKey] logRequestWithValue:reportedValue version:reportedVersion variation:reportedVariation defaultValue:defaultValue];
}

@end

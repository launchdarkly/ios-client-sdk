//
//  LDFlagCounter.m
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagCounter.h"
#import "LDFlagValueCounter.h"
#import "LDFlagConfigValue.h"

NSString * const kLDFlagCounterKeyDefaultValue = @"default";
NSString * const kLDFlagCounterKeyCounters = @"counters";

@interface LDFlagCounter()
@property (nonatomic, strong) NSString *flagKey;
@property (nonatomic, strong) NSMutableArray<LDFlagValueCounter*> *flagValueCounters;
@end

@implementation LDFlagCounter
+(instancetype)counterWithFlagKey:(NSString*)flagKey defaultValue:(id)defaultValue {
    return [[LDFlagCounter alloc] initWithFlagKey:flagKey defaultValue:defaultValue];
}

-(instancetype)initWithFlagKey:(NSString*)flagKey defaultValue:(id)defaultValue {
    if (!(self = [super init])) { return nil; }

    @synchronized(self) {
        self.flagKey = flagKey;
        self.defaultValue = defaultValue;
        self.flagValueCounters = [NSMutableArray array];

        return self;
    }
}

-(BOOL)hasLoggedRequests {
    @synchronized(self) {
        return self.flagValueCounters.count > 0;
    }
}

-(void)logRequestWithFlagConfigValue:(LDFlagConfigValue*)flagConfigValue reportedFlagValue:(id)reportedFlagValue {
    if (reportedFlagValue == nil) {
        reportedFlagValue = [NSNull null];
    }
    @synchronized(self) {
        LDFlagValueCounter *selectedFlagValueCounter = [self valueCounterForFlagConfigValue:flagConfigValue];
        if (selectedFlagValueCounter) {
            selectedFlagValueCounter.count += 1;
            return;
        }

        [self.flagValueCounters addObject:[LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue reportedFlagValue:reportedFlagValue]];
    }
}

-(LDFlagValueCounter*)valueCounterForFlagConfigValue:(LDFlagConfigValue*)flagConfigValue {
    NSPredicate *variationPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        if (![evaluatedObject isKindOfClass:[LDFlagValueCounter class]]) { return NO; }
        LDFlagValueCounter *evaluatedFlagValueCounter = evaluatedObject;
        return (!flagConfigValue && !evaluatedFlagValueCounter.isKnown) || (flagConfigValue && [evaluatedFlagValueCounter.flagConfigValue isEqual:flagConfigValue]);
    }];
    return [[self.flagValueCounters filteredArrayUsingPredicate:variationPredicate] firstObject];
}

-(NSDictionary*)dictionaryValue {
    @synchronized(self) {
        NSMutableArray<NSDictionary*> *flagValueCounterDictionaries = [NSMutableArray arrayWithCapacity:self.flagValueCounters.count];
        NSArray<LDFlagValueCounter*> *flagValueCounters = [NSArray arrayWithArray: self.flagValueCounters];
        for (LDFlagValueCounter *flagValueCounter in flagValueCounters) {
            NSMutableDictionary *flagValueCounterDictionary = [NSMutableDictionary dictionaryWithDictionary:[flagValueCounter dictionaryValue]];
            //If the flagConfigValue.value is nil or null, the client will have served the default value
            if (!flagValueCounter.flagConfigValue.value || [flagValueCounter.flagConfigValue.value isKindOfClass:[NSNull class]]) {
                flagValueCounterDictionary[kLDFlagConfigValueKeyValue] = self.defaultValue ?: [NSNull null];
            }
            [flagValueCounterDictionaries addObject:[flagValueCounterDictionary copy]];
        }
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        if (self.defaultValue) {
            dictionary[kLDFlagCounterKeyDefaultValue] = self.defaultValue;
        } else {
            dictionary[kLDFlagCounterKeyDefaultValue] = [NSNull null];
        }
        dictionary[kLDFlagCounterKeyCounters] = flagValueCounterDictionaries;

        return [NSDictionary dictionaryWithDictionary:dictionary];
    }
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagCounter: %p, flagKey: %@, defaultValue: %@, flagValueCounters: %@>",
            self,
            self.flagKey,
            [self.defaultValue description],
            [self.flagValueCounters description]];
}

@end

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

    self.flagKey = flagKey;
    self.defaultValue = defaultValue;
    self.flagValueCounters = [NSMutableArray array];

    return self;
}

-(NSArray<LDFlagValueCounter*>*)valueCounters {
    return self.flagValueCounters;
}

-(void)logRequestWithFlagConfigValue:(LDFlagConfigValue*)flagConfigValue defaultValue:(id)defaultValue {
    LDFlagValueCounter *selectedFlagValueCounter = [self valueCounterForFlagConfigValue:flagConfigValue];
    if (selectedFlagValueCounter) {
        selectedFlagValueCounter.count += 1;
        return;
    }

    [self.flagValueCounters addObject:[LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue]];
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
    NSMutableArray<NSDictionary*> *flagValueCounterDictionaries = [NSMutableArray arrayWithCapacity:self.flagValueCounters.count];
    for (LDFlagValueCounter *flagValueCounter in self.flagValueCounters) {
        [flagValueCounterDictionaries addObject:[flagValueCounter dictionaryValue]];
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

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagCounter: %p, flagKey: %@, defaultValue: %@, flagValueCounters: %@>",
            self,
            self.flagKey,
            [self.defaultValue description],
            [self.flagValueCounters description]];
}

@end

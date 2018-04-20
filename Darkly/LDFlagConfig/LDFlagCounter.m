//
//  LDFlagCounter.m
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagCounter.h"

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
    return _flagValueCounters;
}

-(LDFlagValueCounter*)valueCounterForVariation:(NSInteger)variation {
    NSPredicate *variationPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        if (![evaluatedObject isKindOfClass:[LDFlagValueCounter class]]) { return NO; }
        return ((LDFlagValueCounter*)evaluatedObject).variation == variation;
    }];
    return [[self.flagValueCounters filteredArrayUsingPredicate:variationPredicate] firstObject];
}

-(void)logRequestWithValue:(id)value version:(NSInteger)version variation:(NSInteger)variation defaultValue:(id)defaultValue {
    LDFlagValueCounter *selectedFlagValueCounter = [self valueCounterForVariation:variation];
    if (selectedFlagValueCounter) {
        selectedFlagValueCounter.count += 1;
        return;
    }

    [self.flagValueCounters addObject:[LDFlagValueCounter counterWithValue:value variation:variation version:version]];
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

@end

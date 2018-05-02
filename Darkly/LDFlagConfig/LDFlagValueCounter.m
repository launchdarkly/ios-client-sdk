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
@property (nonatomic, strong) id value;
@property (nonatomic, assign) NSInteger variation;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, assign, getter=isKnown) BOOL known;
@end

@implementation LDFlagValueCounter
+(instancetype)counterWithFlagConfigValue:(LDFlagConfigValue*)flagConfigValue {
    return [[LDFlagValueCounter alloc] initWithFlagConfigValue:flagConfigValue];
}

-(instancetype)initWithFlagConfigValue:(LDFlagConfigValue*)flagConfigValue {
    if (!(self = [super init])) { return nil; }

    self.flagConfigValue = flagConfigValue;
    self.known = self.flagConfigValue != nil;
    self.count = 1;

    return self;
}

+(instancetype)counterWithValue:(id)value variation:(NSInteger)variation version:(NSInteger)version isKnownValue:(BOOL)isKnownValue {
    return [[LDFlagValueCounter alloc] initWithValue:value variation:variation version:version isKnownValue:isKnownValue];
}

-(instancetype)initWithValue:(id)value variation:(NSInteger)variation version:(NSInteger)version isKnownValue:(BOOL)isKnownValue {
    if (!(self = [super init])) { return nil; }

    self.value = value;
    self.variation = variation;
    self.version = version;
    self.known = isKnownValue;
    self.count = 1;
    
    return self;
}

-(NSDictionary*)dictionaryValue {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:3];

    if (self.known) {
        if (self.flagConfigValue) {
            [dictionary addEntriesFromDictionary:[self.flagConfigValue dictionaryValue]];
        } else {
            dictionary[kLDFlagValueCounterKeyValue] = self.value ?: [NSNull null];
            dictionary[kLDFlagValueCounterKeyVersion] = @(self.version);
            dictionary[kLDFlagValueCounterKeyVariation] = @(self.variation);
        }
    } else {
        dictionary[kLDFlagValueCounterKeyUnknown] = @(YES);
    }
    dictionary[kLDFlagValueCounterKeyCount] = @(self.count);

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagValueCounter: %p, flagConfigValue: %@, value: %@, count: %ld, version: %ld, variation: %ld, known: %@>",
            self, [self.flagConfigValue description], [self.value description], (long)self.count, (long)self.version, (long)self.variation, self.known ? @"YES" : @"NO"];
}

@end

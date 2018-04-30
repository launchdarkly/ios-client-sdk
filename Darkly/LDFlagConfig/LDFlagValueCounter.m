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

NSString * const kLDFlagValueCounterKeyValue = @"value";
NSString * const kLDFlagValueCounterKeyVersion = @"version";
NSString * const kLDFlagValueCounterKeyCount = @"count";
NSString * const kLDFlagValueCounterKeyUnknown = @"unknown";

@interface LDFlagValueCounter()
@property (nonatomic, strong) id value;
@property (nonatomic, assign) NSInteger variation;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, assign, getter=isKnown) BOOL known;
@end

@implementation LDFlagValueCounter
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
        if (self.value) {
            dictionary[kLDFlagValueCounterKeyValue] = self.value;
        }
        if (self.version != kLDFlagConfigVersionDoesNotExist) {
            dictionary[kLDFlagValueCounterKeyVersion] = @(self.version);
        }
    } else {
        dictionary[kLDFlagValueCounterKeyUnknown] = @(YES);
    }
    dictionary[kLDFlagValueCounterKeyCount] = @(self.count);

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagValueCounter: %p, value: %@, count: %ld, version: %ld, variation: %ld, known: %@>",
            self,
            [self.value description],
            (long)self.count,
            (long)self.version,
            (long)self.variation,
            self.known ? @"YES" : @"NO"];
}

@end

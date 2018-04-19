//
//  LDFlagValueCounter.m
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagValueCounter.h"

extern const NSInteger kLDFlagConfigVersionDoesNotExist;
const NSInteger kLDFlagConfigVariationDoesNotExist = -1;    //TODO: When adding the new streaming data model, replace this with an extern reference to this value from the LDFlagConfigValue

NSString * const kLDFlagValueCounterKeyValue = @"value";
NSString * const kLDFlagValueCounterKeyVersion = @"version";
NSString * const kLDFlagValueCounterKeyCount = @"count";
NSString * const kLDFlagValueCounterKeyUnknown = @"unknown";

@interface LDFlagValueCounter()
@property (nonatomic, strong) id value;
@property (nonatomic, assign) NSInteger variation;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, assign, getter=isUnknown) BOOL unknown;
@end

@implementation LDFlagValueCounter
+(instancetype)counterWithValue:(id)value variation:(NSInteger)variation version:(NSInteger)version {
    return [[LDFlagValueCounter alloc] initWithValue:value variation:variation version:version];
}

-(instancetype)initWithValue:(id)value variation:(NSInteger)variation version:(NSInteger)version {
    if (!(self = [super init])) { return nil; }

    self.value = value;
    self.variation = variation;
    self.version = version;
    self.unknown = variation == kLDFlagConfigVariationDoesNotExist;
    self.count = 1;
    
    return self;
}

-(NSDictionary*)dictionaryValue {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:3];


    if (self.unknown) {
        dictionary[kLDFlagValueCounterKeyUnknown] = @(self.unknown);
    } else {
        if (self.value) {
            dictionary[kLDFlagValueCounterKeyValue] = self.value;
        }
        if (self.version != kLDFlagConfigVersionDoesNotExist) {
            dictionary[kLDFlagValueCounterKeyVersion] = @(self.version);
        }
    }
    dictionary[kLDFlagValueCounterKeyCount] = @(self.count);

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

@end

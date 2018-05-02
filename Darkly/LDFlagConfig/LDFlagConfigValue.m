//
//  LDFlagValue.m
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagConfigValue.h"
#import "NSObject+LDFlagConfigValue.h"
#import "LDUtil.h"

NSString * const kLDFlagConfigValueKeyValue = @"value";
NSString * const kLDFlagConfigValueKeyVersion = @"version";
NSString * const kLDFlagConfigValueKeyVariation = @"variation";

NSInteger const kLDFlagConfigVersionDoesNotExist = -1;
NSInteger const kLDFlagConfigVariationDoesNotExist = -1;

@implementation LDFlagConfigValue

+(instancetype)flagConfigValueWithObject:(id)object {
    return [[LDFlagConfigValue alloc] initWithObject:object];
}

-(instancetype)initWithObject:(id)object {
    if (!object) { return nil; }
    if (!(self = [super init])) { return nil; }
    if ([object isValueAndVersionDictionary]) {
        NSDictionary *valueAndVersionDictionary = object;
        self.value = valueAndVersionDictionary[kLDFlagConfigValueKeyValue] ?: [NSNull null];
        self.version = [valueAndVersionDictionary[kLDFlagConfigValueKeyVersion] integerValue];
        self.variation = valueAndVersionDictionary[kLDFlagConfigValueKeyVariation] ? [valueAndVersionDictionary[kLDFlagConfigValueKeyVariation] integerValue] : kLDFlagConfigVariationDoesNotExist;
    } else {
        self.value = object ?: [NSNull null];
        self.version = kLDFlagConfigVersionDoesNotExist;
        self.variation = kLDFlagConfigVariationDoesNotExist;
    }

    return self;
}

-(void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.value forKey:kLDFlagConfigValueKeyValue];
    [encoder encodeInteger:self.version forKey:kLDFlagConfigValueKeyVersion];
    [encoder encodeInteger:self.variation forKey:kLDFlagConfigValueKeyVariation];
}

-(id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [super init])) { return nil; }

    self.value = [decoder decodeObjectForKey:kLDFlagConfigValueKeyValue];
    self.version = [decoder decodeIntegerForKey:kLDFlagConfigValueKeyVersion];
    self.variation = [decoder decodeIntegerForKey:kLDFlagConfigValueKeyVariation];

    return self;
}

-(NSDictionary*)dictionaryValue {
    NSMutableDictionary *dictionaryValue = [NSMutableDictionary dictionaryWithCapacity:3];
    dictionaryValue[kLDFlagConfigValueKeyValue] = self.value ?: [NSNull null];
    if (self.version != kLDFlagConfigVersionDoesNotExist) {
        dictionaryValue[kLDFlagConfigValueKeyVersion] = @(self.version);
    }
    if (self.variation != kLDFlagConfigVariationDoesNotExist) {
        dictionaryValue[kLDFlagConfigValueKeyVariation] = @(self.variation);
    }
    return dictionaryValue;
}

-(BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[LDFlagConfigValue class]]) { return NO; }
    LDFlagConfigValue *other = object;

    return [self.value isEqual:other.value] && self.version == other.version && self.variation == other.variation;
}

-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary {
    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];

    if (self.value) {
        if (![self.value isEqual:dictionary[kLDFlagConfigValueKeyValue]]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyValue];
        }
    } else {
        if (dictionary[kLDFlagConfigValueKeyValue] && ![dictionary[kLDFlagConfigValueKeyValue] isKindOfClass:[NSNull class]]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyValue];
        }
    }

    if (self.version == kLDFlagConfigVersionDoesNotExist) {
        if (dictionary[kLDFlagConfigValueKeyVersion]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVersion];
        }
    } else {
        if (self.version != [dictionary[kLDFlagConfigValueKeyVersion] integerValue]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVersion];
        }
    }

    if (self.variation == kLDFlagConfigVariationDoesNotExist) {
        if (dictionary[kLDFlagConfigValueKeyVariation]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVariation];
        }
    } else {
        if (self.variation != [dictionary[kLDFlagConfigValueKeyVariation] integerValue]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVariation];
        }
    }

    if (mismatchedProperties.count > 0) {
        DEBUG_LOG(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }
    return YES;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagConfigValue: %p, value: %@, version: %ld, variation: %ld>", self, [self.value description], (long)self.version, (long)self.variation];
}
@end

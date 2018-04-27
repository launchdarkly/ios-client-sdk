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
        self.value = valueAndVersionDictionary[kLDFlagConfigValueKeyValue];
        self.version = [valueAndVersionDictionary[kLDFlagConfigValueKeyVersion] integerValue];
        self.variation = valueAndVersionDictionary[kLDFlagConfigValueKeyVariation] ?
            [valueAndVersionDictionary[kLDFlagConfigValueKeyVariation] integerValue] : kLDFlagConfigVariationDoesNotExist;
    } else {
        self.value = object;
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
    return @{kLDFlagConfigValueKeyValue:self.value, kLDFlagConfigValueKeyVersion:@(self.version)};  //TODO: Add variation when server support is added
}

-(BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[LDFlagConfigValue class]]) { return NO; }
    LDFlagConfigValue *other = object;

    return [self.value isEqual:other.value] && self.version == other.version && self.variation == other.variation;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagConfigValue: %p, value: %@, version: %ld, variation: %ld>", self, [self.value description], (long)self.version, (long)self.variation];
}
@end

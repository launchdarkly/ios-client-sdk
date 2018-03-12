//
//  LDFlagValue.m
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigValue.h"
#import "NSObject+LDFlagConfigValue.h"

NSString * const kLDFlagConfigJsonDictionaryKeyValue = @"value";
NSString * const kLDFlagConfigJsonDictionaryKeyVersion = @"version";

NSInteger const kLDFlagConfigVersionDoesNotExist = -1;

@implementation LDFlagConfigValue

+(instancetype)flagConfigValueWithObject:(id)object {
    return [[LDFlagConfigValue alloc] initWithObject:object];
}

-(instancetype)initWithObject:(id)object {
    if (!object) { return nil; }
    if (!(self = [super init])) { return nil; }
    if ([object isValueAndVersionDictionary]) {
        NSDictionary *valueAndVersionDictionary = object;
        _value = valueAndVersionDictionary[kLDFlagConfigJsonDictionaryKeyValue];
        _version = [(NSNumber*)valueAndVersionDictionary[kLDFlagConfigJsonDictionaryKeyVersion] integerValue];
    } else {
        _value = object;
        _version = kLDFlagConfigVersionDoesNotExist;
    }

    return self;
}

-(void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.value forKey:kLDFlagConfigJsonDictionaryKeyValue];
    [encoder encodeInteger:self.version forKey:kLDFlagConfigJsonDictionaryKeyVersion];
}

-(id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [super init])) { return nil; }

    _value = [decoder decodeObjectForKey:kLDFlagConfigJsonDictionaryKeyValue];
    _version = [decoder decodeIntegerForKey:kLDFlagConfigJsonDictionaryKeyVersion];

    return self;
}

-(NSDictionary*)dictionaryValue {
    return @{kLDFlagConfigJsonDictionaryKeyValue: self.value, kLDFlagConfigJsonDictionaryKeyVersion: @(self.version)};
}

-(BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[LDFlagConfigValue class]]) { return NO; }
    LDFlagConfigValue *other = object;

    return [self.value isEqual:other.value] && self.version == other.version;
}
@end

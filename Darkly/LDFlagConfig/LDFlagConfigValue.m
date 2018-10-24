//
//  LDFlagValue.m
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagConfigValue.h"
#import "LDEventTrackingContext.h"
#import "LDUtil.h"

NSString * const kLDFlagConfigValueKeyValue = @"value";
NSString * const kLDFlagConfigValueKeyVersion = @"version";
NSString * const kLDFlagConfigValueKeyVariation = @"variation";
NSString * const kLDFlagConfigValueKeyFlagVersion = @"flagVersion";
NSString * const kLDFlagConfigValueKeyEventTrackingContext = @"eventTrackingContext";

NSInteger const kLDFlagConfigValueItemDoesNotExist = -1;

@implementation LDFlagConfigValue

+(instancetype)flagConfigValueWithObject:(id)object {
    return [[LDFlagConfigValue alloc] initWithObject:object];
}

-(instancetype)initWithObject:(id)object {
    if (object == nil) { return nil; }
    if (!(self = [super init])) { return nil; }
    if (![object isKindOfClass:[NSDictionary class]]) {
        //The object is not a LDFlagConfigValue dictionary. Assume that it's from a dictionary of flagKey: flagValue elements, as it would be in an older user cache
        self.value = object;
        self.modelVersion = kLDFlagConfigValueItemDoesNotExist;
        self.variation = kLDFlagConfigValueItemDoesNotExist;
        self.flagVersion = nil;
        self.eventTrackingContext = nil;
        return self;
    }
    NSDictionary *flagConfigValueDictionary = object;
    self.modelVersion = kLDFlagConfigValueItemDoesNotExist;
    if (flagConfigValueDictionary[kLDFlagConfigValueKeyVersion] != nil && [flagConfigValueDictionary[kLDFlagConfigValueKeyVersion] isKindOfClass:[NSNumber class]]) {
        self.modelVersion = [flagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue];
    }
    self.flagVersion = nil;
    if (flagConfigValueDictionary[kLDFlagConfigValueKeyFlagVersion] != nil && [flagConfigValueDictionary[kLDFlagConfigValueKeyFlagVersion] isKindOfClass:[NSNumber class]]) {
        self.flagVersion = flagConfigValueDictionary[kLDFlagConfigValueKeyFlagVersion];
    }
    self.variation = kLDFlagConfigValueItemDoesNotExist;
    if (flagConfigValueDictionary[kLDFlagConfigValueKeyVariation] != nil && [flagConfigValueDictionary[kLDFlagConfigValueKeyVariation] isKindOfClass:[NSNumber class]]) {
        self.variation = [flagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue];
    }
    self.value = flagConfigValueDictionary[kLDFlagConfigValueKeyValue];
    if (self.value == nil) {
        //If the value isn't in the dictionary, then the dictionary might not be a flagConfigValue dictionary, or the value might just be missing. Check other elements to decide.
        if (self.modelVersion != kLDFlagConfigValueItemDoesNotExist || self.flagVersion != nil || self.variation != kLDFlagConfigValueItemDoesNotExist) {
            //At least one other item in a LDFlagConfigValue dictionary exists
            self.value = [NSNull null];
        } else {
            //None of the other items in a LDFlagConfigValue dictionary exist. Assume the dictionary is the flag value
            self.value = flagConfigValueDictionary;
        }
    }
    self.eventTrackingContext = [LDEventTrackingContext contextWithObject:object];

    return self;
}

-(void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.value forKey:kLDFlagConfigValueKeyValue];
    [encoder encodeInteger:self.modelVersion forKey:kLDFlagConfigValueKeyVersion];
    [encoder encodeInteger:self.variation forKey:kLDFlagConfigValueKeyVariation];
    [encoder encodeObject:self.flagVersion forKey:kLDFlagConfigValueKeyFlagVersion];
    [encoder encodeObject:self.eventTrackingContext forKey:kLDFlagConfigValueKeyEventTrackingContext];
}

-(id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [super init])) { return nil; }

    self.value = [decoder decodeObjectForKey:kLDFlagConfigValueKeyValue];
    self.modelVersion = [decoder decodeIntegerForKey:kLDFlagConfigValueKeyVersion];
    self.variation = [decoder decodeIntegerForKey:kLDFlagConfigValueKeyVariation];
    self.flagVersion = [decoder decodeObjectForKey:kLDFlagConfigValueKeyFlagVersion];
    self.eventTrackingContext = [decoder decodeObjectForKey:kLDFlagConfigValueKeyEventTrackingContext];

    return self;
}

-(NSDictionary*)dictionaryValue {
    return [self dictionaryValueUseFlagVersionForVersion:NO includeEventTrackingContext:YES];
}

-(NSDictionary*)dictionaryValueUseFlagVersionForVersion:(BOOL)useFlagVersion includeEventTrackingContext:(BOOL)includeEventTrackingContext {
    NSMutableDictionary *dictionaryValue = [NSMutableDictionary dictionaryWithCapacity:5];
    dictionaryValue[kLDFlagConfigValueKeyValue] = self.value ?: [NSNull null];
    if (self.modelVersion != kLDFlagConfigValueItemDoesNotExist) {
        dictionaryValue[kLDFlagConfigValueKeyVersion] = @(self.modelVersion);
    }
    if (self.flagVersion != nil) {
        NSString *versionKey = useFlagVersion ? kLDFlagConfigValueKeyVersion : kLDFlagConfigValueKeyFlagVersion;
        dictionaryValue[versionKey] = self.flagVersion;
    }
    if (self.variation != kLDFlagConfigValueItemDoesNotExist) {
        dictionaryValue[kLDFlagConfigValueKeyVariation] = @(self.variation);
    }
    if (self.eventTrackingContext && includeEventTrackingContext) {
        [dictionaryValue addEntriesFromDictionary:[self.eventTrackingContext dictionaryValue]];
    }
    return dictionaryValue;
}

-(BOOL)isEqualToFlagConfigValue:(LDFlagConfigValue*)other {
    if (!other) { return NO; }
    if (self == other) { return YES; }

    return self.variation == other.variation && self.modelVersion == other.modelVersion;
}

-(BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[LDFlagConfigValue class]]) { return NO; }
    LDFlagConfigValue *other = object;

    return [self isEqualToFlagConfigValue:other];
}

-(NSUInteger)hash {
    return labs(self.variation) ^ labs(self.modelVersion);
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

    if (self.variation == kLDFlagConfigValueItemDoesNotExist) {
        if (dictionary[kLDFlagConfigValueKeyVariation]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVariation];
        }
    } else {
        if (!dictionary[kLDFlagConfigValueKeyVariation] || self.variation != [dictionary[kLDFlagConfigValueKeyVariation] integerValue]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVariation];
        }
    }

    if (self.modelVersion == kLDFlagConfigValueItemDoesNotExist) {
        if (dictionary[kLDFlagConfigValueKeyVersion]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVersion];
        }
    } else {
        if (!dictionary[kLDFlagConfigValueKeyVersion] || self.modelVersion != [dictionary[kLDFlagConfigValueKeyVersion] integerValue]) {
            [mismatchedProperties addObject:kLDFlagConfigValueKeyVersion];
        }
    }

    if (mismatchedProperties.count > 0) {
        DEBUG_LOG(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }
    return YES;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagConfigValue: %p, value: %@, modelVersion: %ld, variation: %ld, flagVersion: %@, eventTrackingContext: %@>", self, [self.value description], (long)self.modelVersion, (long)self.variation, self.flagVersion != nil ? [self.flagVersion description] : @"nil", self.eventTrackingContext ?: @"nil"];
}
@end

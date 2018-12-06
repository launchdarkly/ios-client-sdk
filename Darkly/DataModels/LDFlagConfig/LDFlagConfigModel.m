//
//  LDFlagConfigModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDFlagConfigValue.h"
#import "LDUtil.h"
#import "NSMutableDictionary+NullRemovable.h"
#import "NSDictionary+LaunchDarkly.h"

NSString * const kFeaturesJsonDictionaryKey = @"featuresJsonDictionary";
NSString * const kLDFlagConfigModelKeyKey = @"key";

@implementation LDFlagConfigModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.featuresJsonDictionary forKey:kFeaturesJsonDictionaryKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [self init])) { return nil; }

    self.featuresJsonDictionary = [decoder decodeObjectForKey:kFeaturesJsonDictionaryKey];

    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (!(self = [self init])) { return nil; }

    NSMutableDictionary *flagConfigValues = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (NSString *key in [dictionary.allKeys copy]) {
        flagConfigValues[key] = [LDFlagConfigValue flagConfigValueWithObject:dictionary[key]];
    }

    self.featuresJsonDictionary = [NSDictionary dictionaryWithDictionary:[flagConfigValues copy]];

    return self;
}

-(instancetype)init {
    if (!(self = [super init])) { return nil; }

    self.featuresJsonDictionary = @{};

    return self;
}

-(NSDictionary *)dictionaryValue {
    return [self dictionaryValueIncludeNulls:YES];
}

-(NSDictionary*)dictionaryValueIncludeNulls:(BOOL)includeNulls {
    if (!self.featuresJsonDictionary) return nil;

    NSDictionary *featuresJsonDictionary = [self.featuresJsonDictionary copy];
    NSMutableDictionary *flagConfigDictionaryValues = [NSMutableDictionary dictionaryWithCapacity:featuresJsonDictionary.count];
    for (NSString *key in featuresJsonDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = featuresJsonDictionary[key];
        if (![flagConfigValue isKindOfClass:[LDFlagConfigValue class]]) {
            DEBUG_LOG(@"LDFlagConfigModel dictionaryValueIncludeNulls: found an invalid value for key:%@. Skipping without putting the value into the dictionary.", key);
            continue;   //The value coming out of the featuresJsonDictionary is not a LDFlagConfigValue. Skip it.
        }
        if (!includeNulls && [flagConfigValue.value isKindOfClass:[NSNull class]]) {
            continue;
        }
        NSDictionary *flagConfigValueDictionary = [flagConfigValue dictionaryValue];
        flagConfigDictionaryValues[key] = flagConfigValueDictionary;
    }
    if (!includeNulls) {
        [flagConfigDictionaryValues removeNullValues];  //Redact nulls out of values that are dictionaries
    }

    return [NSDictionary dictionaryWithDictionary:[flagConfigDictionaryValues copy]];
}

-(NSDictionary*)allFlagValues {
    return [self.featuresJsonDictionary compactMapUsingBlock:^id(id originalValue) {
        if (originalValue == nil) { return nil; }
        if (![originalValue isKindOfClass:[LDFlagConfigValue class]]) { return nil; }
        LDFlagConfigValue *flagConfigValue = originalValue;
        if (flagConfigValue.value == nil || [flagConfigValue.value isKindOfClass:[NSNull class]]) { return nil; }
        return flagConfigValue.value;
    }];
}

-(BOOL)containsFlagKey:(NSString*)flagKey {
    if (!self.featuresJsonDictionary) { return NO; }

    return [[self.featuresJsonDictionary allKeys] containsObject: flagKey];
}

-(LDFlagConfigValue*)flagConfigValueForFlagKey:(NSString*)flagKey {
    return self.featuresJsonDictionary[flagKey];
}

-(id)flagValueForFlagKey:(NSString*)flagKey {
    LDFlagConfigValue *featureValue = self.featuresJsonDictionary[flagKey];
    if (!featureValue || [featureValue.value isKindOfClass:[NSNull class]]) {
        return nil;
    }
    
    return featureValue.value;
}

-(NSInteger)flagModelVersionForFlagKey:(NSString*)flagKey {
    LDFlagConfigValue *featureValue = self.featuresJsonDictionary[flagKey];
    if (!featureValue) { return kLDFlagConfigValueItemDoesNotExist; }

    return featureValue.modelVersion;
}

-(void)addOrReplaceFromDictionary:(NSDictionary*)eventDictionary {
    NSString *flagKey = eventDictionary[kLDFlagConfigModelKeyKey];
    LDFlagConfigValue *patchedFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:eventDictionary];
    if (![self shouldApplyPatch:patchedFlagConfigValue forFlagKey:flagKey]) { return; }

    NSMutableDictionary *updatedFlagConfig = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
    updatedFlagConfig[flagKey] = patchedFlagConfigValue;
    self.featuresJsonDictionary = [updatedFlagConfig copy];
}

-(BOOL)shouldApplyPatch:(LDFlagConfigValue*)patchedFlagConfigValue forFlagKey:(NSString*)flagKey {
    if (flagKey.length == 0) { return NO; }
    if (!patchedFlagConfigValue) { return NO; }
    if (patchedFlagConfigValue.modelVersion == kLDFlagConfigValueItemDoesNotExist) { return YES; }
    LDFlagConfigValue *currentFlagConfigValue = [self flagConfigValueForFlagKey:flagKey];
    if (!currentFlagConfigValue) { return YES; }
    if (currentFlagConfigValue.modelVersion == kLDFlagConfigValueItemDoesNotExist) { return YES; }
    return patchedFlagConfigValue.modelVersion > [self flagModelVersionForFlagKey:flagKey];
}

-(void)deleteFromDictionary:(NSDictionary*)eventDictionary {
    NSString *flagKey = eventDictionary[kLDFlagConfigModelKeyKey];
    if (flagKey.length == 0) { return; }

    id flagVersionObject = eventDictionary[kLDFlagConfigValueKeyVersion];
    if (!flagVersionObject || ![flagVersionObject isKindOfClass:[NSNumber class]]) { return; }
    NSInteger flagVersion = [(NSNumber*)flagVersionObject integerValue];
    if ([self containsFlagKey:flagKey] && flagVersion <= [self flagModelVersionForFlagKey:flagKey]) { return; }

    NSMutableDictionary *updatedFlagConfig = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
    [updatedFlagConfig removeObjectForKey:flagKey];

    self.featuresJsonDictionary = [updatedFlagConfig copy];
}

-(BOOL)isEqualToConfig:(LDFlagConfigModel *)otherConfig {
    return [self.featuresJsonDictionary isEqualToDictionary:otherConfig.featuresJsonDictionary];
}

-(NSArray<NSString*>*)differingFlagKeysFromConfig:(nullable LDFlagConfigModel*)otherConfig {
    NSSet<NSString*> *allKeys = [[NSSet setWithArray:self.featuresJsonDictionary.allKeys] setByAddingObjectsFromArray:otherConfig.featuresJsonDictionary.allKeys];
    NSMutableArray<NSString*> *differingFlagKeys = [NSMutableArray arrayWithCapacity:allKeys.count];
    for (NSString *flagKey in allKeys) {
        if (![self containsFlagKey:flagKey] || ![otherConfig containsFlagKey:flagKey]) {
            [differingFlagKeys addObject:flagKey];
            continue;
        }
        id value = [self flagValueForFlagKey:flagKey];
        id otherValue = [otherConfig flagValueForFlagKey:flagKey];
        if ([value isEqual:otherValue]) {
            continue;
        }
        if (value == nil && otherValue == nil) {
            continue;
        }
        [differingFlagKeys addObject:flagKey];
    }
    if (differingFlagKeys.count == 0) {
        return nil;
    }

    return [differingFlagKeys copy];
}

-(BOOL)hasFeaturesEqualToDictionary:(NSDictionary*)otherDictionary {
    NSArray<NSString*> *flagKeys = self.featuresJsonDictionary.allKeys;
    if (flagKeys.count != otherDictionary.allKeys.count) {
        return NO;
    }
    for (NSString *flagKey in flagKeys) {
        LDFlagConfigValue *flagConfigValue = self.featuresJsonDictionary[flagKey];
        if (!otherDictionary[flagKey] || ![otherDictionary[flagKey] isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        NSDictionary *otherFlagConfigValueDictionary = otherDictionary[flagKey];

        if (![flagConfigValue hasPropertiesMatchingDictionary:otherFlagConfigValueDictionary]) {
            return NO;
        }
    }
    return YES;
}

-(void)updateEventTrackingContextFromConfig:(LDFlagConfigModel*)otherConfig {
    if (!otherConfig || otherConfig.featuresJsonDictionary.count == 0) {
        DEBUG_LOGX(@"LDFlagConfigModel updateEventTrackingContext found missing or empty otherConfig. Aborting.");
        return;
    }
    for (NSString *flagKey in [self.featuresJsonDictionary.allKeys copy]) {
        LDFlagConfigValue *otherFlagConfigValue = otherConfig.featuresJsonDictionary[flagKey];
        if (!otherFlagConfigValue) { continue; }
        LDFlagConfigValue *flagConfigValue = self.featuresJsonDictionary[flagKey];
        if (!flagConfigValue) { continue; }
        flagConfigValue.eventTrackingContext = otherFlagConfigValue.eventTrackingContext;
    }
}

-(LDFlagConfigModel*)copy {
    return [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryValueIncludeNulls:YES]];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagConfigModel: %p, featuresJsonDictionary: %@>", self, [self.featuresJsonDictionary description]];
}

@end

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

    NSMutableDictionary *flagConfigDictionaryValues = [NSMutableDictionary dictionaryWithCapacity:self.featuresJsonDictionary.count];
    for (NSString *key in [self.featuresJsonDictionary.allKeys copy]) {
        if (!includeNulls && [self.featuresJsonDictionary[key].value isKindOfClass:[NSNull class]]) { continue; }
        flagConfigDictionaryValues[key] = [self.featuresJsonDictionary[key] dictionaryValue];
    }
    if (!includeNulls) {
        [flagConfigDictionaryValues removeNullValues];  //Redact nulls out of values that are dictionaries
    }

    return [NSDictionary dictionaryWithDictionary:[flagConfigDictionaryValues copy]];
}

-(BOOL)doesFlagConfigValueExistForFlagKey:(NSString*)flagKey {
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

-(void)addOrReplaceFromDictionary:(NSDictionary*)patch {
    NSString *flagKey = patch[kLDFlagConfigModelKeyKey];
    LDFlagConfigValue *patchedFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:patch];
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

-(void)deleteFromDictionary:(NSDictionary*)delete {
    NSString *flagKey = delete[kLDFlagConfigModelKeyKey];
    if (flagKey.length == 0) { return; }

    id flagVersionObject = delete[kLDFlagConfigValueKeyVersion];
    if (!flagVersionObject || ![flagVersionObject isKindOfClass:[NSNumber class]]) { return; }
    NSInteger flagVersion = [(NSNumber*)flagVersionObject integerValue];
    if ([self doesFlagConfigValueExistForFlagKey:flagKey] && flagVersion <= [self flagModelVersionForFlagKey:flagKey]) { return; }

    NSMutableDictionary *updatedFlagConfig = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
    updatedFlagConfig[flagKey] = nil;

    self.featuresJsonDictionary = [updatedFlagConfig copy];
}

-(BOOL)isEqualToConfig:(LDFlagConfigModel *)otherConfig {
    return [self.featuresJsonDictionary isEqualToDictionary:otherConfig.featuresJsonDictionary];
}

-(BOOL)hasFeaturesEqualToDictionary:(NSDictionary*)otherDictionary {
    NSArray<NSString*> *flagKeys = self.featuresJsonDictionary.allKeys;
    if (flagKeys.count != otherDictionary.allKeys.count) { return NO; }
    for (NSString *flagKey in flagKeys) {
        LDFlagConfigValue *flagConfigValue = self.featuresJsonDictionary[flagKey];
        if (!otherDictionary[flagKey] || ![otherDictionary[flagKey] isKindOfClass:[NSDictionary class]]) { return NO; }
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

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDFlagConfigModel: %p, featuresJsonDictionary: %@>", self, [self.featuresJsonDictionary description]];
}

@end

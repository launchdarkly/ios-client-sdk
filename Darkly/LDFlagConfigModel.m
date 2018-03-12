//
//  LDFlagConfigModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDUtil.h"
#import "NSMutableDictionary+NullRemovable.h"

NSString * const kFeaturesJsonDictionaryKey = @"featuresJsonDictionary";
NSString * const kLDFlagConfigJsonDictionaryKeyKey = @"key";

extern NSString * const kLDFlagConfigJsonDictionaryKeyValue;
extern NSString * const kLDFlagConfigJsonDictionaryKeyVersion;
extern const NSInteger kLDFlagConfigVersionDoesNotExist;

@implementation LDFlagConfigModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.featuresJsonDictionary forKey:kFeaturesJsonDictionaryKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [super init])) { return nil; }
    _featuresJsonDictionary = [decoder decodeObjectForKey:kFeaturesJsonDictionaryKey];
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (!(self = [super init])) { return nil; }

    NSMutableDictionary *flagConfigValues = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (NSString *key in [dictionary.allKeys copy]) {
        flagConfigValues[key] = [LDFlagConfigValue flagConfigValueWithObject:dictionary[key]];
    }

    _featuresJsonDictionary = [NSDictionary dictionaryWithDictionary:[flagConfigValues copy]];

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

-(id)configFlagValue:(NSString*)keyName {
    LDFlagConfigValue *featureValue = self.featuresJsonDictionary[keyName];
    if (!featureValue || [featureValue.value isKindOfClass:[NSNull class]]) { return nil; }
    
    return featureValue.value;
}

-(NSInteger)configFlagVersion:(NSString*)keyName {
    LDFlagConfigValue *featureValue = self.featuresJsonDictionary[keyName];
    if (!featureValue) { return kLDFlagConfigVersionDoesNotExist; }

    return featureValue.version;
}

-(BOOL)doesConfigFlagExist:(NSString*)keyName {
    if (!self.featuresJsonDictionary) { return NO; }

    return [[self.featuresJsonDictionary allKeys] containsObject: keyName];
}

-(void)addOrReplaceFromDictionary:(NSDictionary*)patch {
    NSString *flagKey = patch[kLDFlagConfigJsonDictionaryKeyKey];
    if (flagKey.length == 0) { return; }

    id flagValue = patch[kLDFlagConfigJsonDictionaryKeyValue];
    if (!flagValue) { return; }

    id flagVersionObject = patch[kLDFlagConfigJsonDictionaryKeyVersion];
    if (!flagVersionObject || ![flagVersionObject isKindOfClass:[NSNumber class]]) { return; }
    NSInteger flagVersion = [(NSNumber*)flagVersionObject integerValue];
    if ([self doesConfigFlagExist:flagKey] && flagVersion <= [self configFlagVersion:flagKey]) { return; }

    NSMutableDictionary *updatedFlagConfig = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
    updatedFlagConfig[flagKey] = [LDFlagConfigValue flagConfigValueWithObject:@{kLDFlagConfigJsonDictionaryKeyValue:flagValue, kLDFlagConfigJsonDictionaryKeyVersion:@(flagVersion)}];
    self.featuresJsonDictionary = [updatedFlagConfig copy];
}

-(void)deleteFromDictionary:(nullable NSDictionary*)delete {
    NSString *flagKey = delete[kLDFlagConfigJsonDictionaryKeyKey];
    if (flagKey.length == 0) { return; }

    id flagVersionObject = delete[kLDFlagConfigJsonDictionaryKeyVersion];
    if (!flagVersionObject || ![flagVersionObject isKindOfClass:[NSNumber class]]) { return; }
    NSInteger flagVersion = [(NSNumber*)flagVersionObject integerValue];
    if ([self doesConfigFlagExist:flagKey] && flagVersion <= [self configFlagVersion:flagKey]) { return; }

    NSMutableDictionary *updatedFlagConfig = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
    updatedFlagConfig[flagKey] = nil;

    self.featuresJsonDictionary = [updatedFlagConfig copy];
}

-(BOOL)isEqualToConfig:(LDFlagConfigModel *)otherConfig {
    return [self.featuresJsonDictionary isEqualToDictionary:otherConfig.featuresJsonDictionary];
}

-(BOOL)hasFeaturesEqualToDictionary:(NSDictionary*)otherDictionary {
    return [[self dictionaryValue] isEqualToDictionary:otherDictionary];
}

@end

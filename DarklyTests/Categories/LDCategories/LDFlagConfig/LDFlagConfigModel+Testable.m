//
//  LDFlagConfigModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDFlagConfigTracker+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"
#import "NSJSONSerialization+Testable.h"
#import "LDEventSource.h"
#import "LDEvent+EventTypes.h"

@implementation LDFlagConfigModel(Testable)

+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName {
    return [LDFlagConfigModel flagConfigFromJsonFileNamed:fileName eventTrackingContext:nil omitKey:nil];
}

+(instancetype)flagConfigWithOnlyFlagValuesFromJsonFileNamed:(NSString *)fileName {
    LDFlagConfigModel *flagConfigModel = [LDFlagConfigModel flagConfigFromJsonFileNamed:fileName];
    NSDictionary<NSString*, LDFlagConfigValue*> *featuresJsonDictionary = flagConfigModel.featuresJsonDictionary;
    NSMutableDictionary *allFlagValues = [NSMutableDictionary dictionaryWithCapacity:featuresJsonDictionary.count];
    for (NSString *flagKey in featuresJsonDictionary.allKeys) {
        id flagValue = featuresJsonDictionary[flagKey].value;
        allFlagValues[flagKey] = flagValue ?: [NSNull null];
    }
    flagConfigModel.featuresJsonDictionary = [allFlagValues copy];

    return flagConfigModel;
}

+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)omitKey {
    return [LDFlagConfigModel flagConfigFromJsonFileNamed:fileName eventTrackingContext:nil omitKey:omitKey];
}

+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext {
    return [LDFlagConfigModel flagConfigFromJsonFileNamed:fileName eventTrackingContext:eventTrackingContext omitKey:nil];
}

+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext omitKey:(NSString*)omitKey {
    NSMutableDictionary *flagConfigModelDictionary = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
    if (eventTrackingContext) {
        for (NSString *flagKey in flagConfigModelDictionary.allKeys) {
            NSMutableDictionary *flagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigModelDictionary[flagKey]];
            [flagConfigValueDictionary addEntriesFromDictionary:[eventTrackingContext dictionaryValue]];
            flagConfigModelDictionary[flagKey] = [flagConfigValueDictionary copy];
        }
    }

    LDFlagConfigModel *flagConfigModel = [[LDFlagConfigModel alloc] initWithDictionary:flagConfigModelDictionary];

    if (omitKey.length > 0) {
        NSMutableDictionary *flagConfigValues = [NSMutableDictionary dictionaryWithDictionary:flagConfigModel.featuresJsonDictionary];
        [flagConfigValues removeObjectForKey:omitKey];
        for (NSString *flagKey in flagConfigValues.allKeys) {
            LDFlagConfigValue *flagConfigValue = flagConfigValues[flagKey];
            if ([omitKey isEqualToString:kLDFlagConfigValueKeyValue]) {
                flagConfigValue.value = nil;
            } else if ([omitKey isEqualToString:kLDFlagConfigValueKeyVersion]) {
                flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
            } else if ([omitKey isEqualToString:kLDFlagConfigValueKeyVariation]) {
                flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;
            }
        }
        flagConfigModel.featuresJsonDictionary = [flagConfigValues copy];
    }

    return flagConfigModel;
}

+(instancetype)stub {
    return [LDFlagConfigModel stubOmittingFlagKeys:nil];
}

+(instancetype)stubWithAlternateValuesForFlagKeys:(NSArray<NSString*>*)alternateValueFlagKeys {
    NSMutableDictionary<NSString*, LDFlagConfigValue*> *featureFlags = [NSMutableDictionary dictionaryWithCapacity:[LDFlagConfigValue flagKeys].count];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        featureFlags[flagKey] = [LDFlagConfigValue stubForFlagKey:flagKey useAlternateValue:[alternateValueFlagKeys containsObject:flagKey]];
    }
    LDFlagConfigModel *flagConfigModel = [[LDFlagConfigModel alloc] init];
    flagConfigModel.featuresJsonDictionary = [featureFlags copy];

    return flagConfigModel;
}

+(instancetype)stubOmittingFlagKeys:(NSArray<NSString*>*)omittedFlagKeys {
    NSMutableArray<NSString*> *includedFlagKeys = [NSMutableArray arrayWithArray:[LDFlagConfigValue flagKeys]];
    [includedFlagKeys removeObjectsInArray:omittedFlagKeys];
    NSMutableDictionary<NSString*, LDFlagConfigValue*> *featureFlags = [NSMutableDictionary dictionaryWithCapacity:includedFlagKeys.count];
    for (NSString *flagKey in [includedFlagKeys copy]) {
        featureFlags[flagKey] = [LDFlagConfigValue stubForFlagKey:flagKey];
    }
    LDFlagConfigModel *flagConfigModel = [[LDFlagConfigModel alloc] init];
    flagConfigModel.featuresJsonDictionary = [featureFlags copy];

    return flagConfigModel;
}

+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version {
    NSMutableDictionary *patch = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
    patch[kLDFlagConfigValueKeyVersion] = @(version);
    return patch;
}

+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key {
    NSMutableDictionary *patch = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
    if (key.length > 0) {
        [patch removeObjectForKey:key];
    }
    return patch;
}

-(LDFlagConfigModel*)applySSEEvent:(LDEvent*)event {
    NSDictionary *eventDictionary = [NSJSONSerialization JSONObjectWithData:[event.data dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
    LDFlagConfigModel *targetFlagConfig = [self copy];
    if ([event.event isEqualToString:kLDEventTypePut]) {
        targetFlagConfig = [[LDFlagConfigModel alloc] initWithDictionary:eventDictionary];
    }
    if ([event.event isEqualToString:kLDEventTypePatch]) {
        NSString *flagKey = eventDictionary[kLDFlagConfigModelKeyKey];
        LDFlagConfigValue *targetFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:eventDictionary];
        [targetFlagConfig setFlagConfigValue:targetFlagConfigValue forKey:flagKey];
    }
    if ([event.event isEqualToString:kLDEventTypeDelete]) {
        NSString *flagKey = eventDictionary[kLDFlagConfigModelKeyKey];
        NSMutableDictionary *flagConfigValues = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
        [flagConfigValues removeObjectForKey:flagKey];
        targetFlagConfig.featuresJsonDictionary = [flagConfigValues copy];
    }
    return targetFlagConfig;
}

+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version {
    return [LDFlagConfigModel patchFromJsonFileNamed:fileName useVersion:version];
}

+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key {
    return [LDFlagConfigModel patchFromJsonFileNamed:fileName omitKey:key];
}

-(void)setFlagConfigValue:(LDFlagConfigValue*)flagConfigValue forKey:(NSString*)flagKey {
    NSMutableDictionary<NSString*, LDFlagConfigValue*> *featureFlags = [NSMutableDictionary dictionaryWithDictionary:self.featuresJsonDictionary];
    featureFlags[flagKey] = flagConfigValue;
    self.featuresJsonDictionary = [featureFlags copy];
}

-(BOOL)isEmpty {
    return self.featuresJsonDictionary.count == 0;
}
@end

//
//  LDFlagConfigModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigTracker+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"
#import "NSJSONSerialization+Testable.h"

@implementation LDFlagConfigModel(Testable)

+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName {
    return [LDFlagConfigModel flagConfigFromJsonFileNamed:fileName eventTrackingContext:nil omitKey:nil];
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

+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version {
    return [LDFlagConfigModel patchFromJsonFileNamed:fileName useVersion:version];
}

+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key {
    return [LDFlagConfigModel patchFromJsonFileNamed:fileName omitKey:key];
}
@end

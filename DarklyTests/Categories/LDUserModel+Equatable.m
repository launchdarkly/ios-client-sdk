//
//  LDUserModel+Equatable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDUserModel+Equatable.h"
#import "NSDictionary+StringKey_Matchable.h"
#import "NSDateFormatter+LDUserModel.h"

@implementation LDUserModel (Equatable)
-(BOOL) isEqual:(id)object ignoringProperties:(NSArray<NSString*>*)ignoredProperties {
    LDUserModel *otherUser = (LDUserModel*)object;
    if (otherUser == nil) {
        return NO;
    }
    NSDictionary *dictionary = [self dictionaryValue];
    NSDictionary *otherDictionary = [otherUser dictionaryValue];
    NSArray *differingKeys = [dictionary keysWithDifferentValuesIn: otherDictionary ignoringKeys: ignoredProperties];
    return (differingKeys == nil || [differingKeys count] == 0);
}

-(BOOL)matchesDictionary:(NSDictionary *)dictionary includeConfig:(BOOL)includeConfig includePrivateProperties:(BOOL)includePrivate privatePropertyNames:(NSArray<NSString*> *)privateProperties {
    NSString *matchingFailureReason = @"Dictionary value does not match LDUserModel property: %@";
    NSString *containsFailureReason = @"Dictionary contains private property: %@";

    if (![self.key isEqualToString:dictionary[kUserPropertyNameKey]]) {
        NSLog(matchingFailureReason, kUserPropertyNameKey);
        return NO;
    }

    NSArray<NSString *> *stringProperties = @[kUserPropertyNameIp, kUserPropertyNameCountry, kUserPropertyNameName, kUserPropertyNameFirstName, kUserPropertyNameLastName, kUserPropertyNameEmail, kUserPropertyNameAvatar];
    for (NSString *propertyName in stringProperties) {
        if (!includePrivate && [privateProperties containsObject:propertyName]) {
            if (dictionary[propertyName] != nil) {
                NSLog(@"Dictionary contains property %@", propertyName);
                return NO;
            }
            continue;
        }
        if (![[self propertyForName:propertyName] isEqualToString:dictionary[propertyName]]) {
            NSLog(matchingFailureReason, propertyName);
            return NO;
        }
    }

    if (![[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] isEqualToString:dictionary[kUserPropertyNameUpdatedAt]]) {
        NSLog(matchingFailureReason, kUserPropertyNameUpdatedAt);
        return NO;
    }

    if (!includePrivate && [privateProperties containsObject:kUserPropertyNameCustom]) {
        if (dictionary[kUserPropertyNameCustom] != nil) {
            NSLog(containsFailureReason, kUserPropertyNameCustom);
            return NO;
        }
    } else {
        NSDictionary *customDictionary = dictionary[kUserPropertyNameCustom];

        for (NSString *propertyName in self.custom.allKeys) {
            if (!includePrivate && [privateProperties containsObject:propertyName]) {
                if (customDictionary[propertyName] != nil) {
                    NSLog(containsFailureReason, propertyName);
                    return NO;
                }
                continue;
            }

            //NOTE: The stubbed custom dictionary only contains string values...
            if ([self.custom[propertyName] isKindOfClass:[NSString class]] && ![self.custom[propertyName] isEqualToString:customDictionary[propertyName]]) {
                NSLog(containsFailureReason, propertyName);
                return NO;
            }
            if (![self.custom[propertyName] isKindOfClass:[NSString class]]) { NSLog(@"WARNING: Non-string type contained in LDUserModel.custom at the key %@", propertyName); }
        }

        NSArray<NSString *> *customStringProperties = @[kUserPropertyNameDevice, kUserPropertyNameOs];
        for (NSString *propertyName in customStringProperties) {
            if ([self propertyForName:propertyName] == nil) { continue; }
            if (!includePrivate && [privateProperties containsObject:propertyName]) {
                if (customDictionary[propertyName] != nil) {
                    NSLog(containsFailureReason, propertyName);
                    return NO;
                }
                continue;
            }
            if (![[self propertyForName:propertyName] isEqualToString:customDictionary[propertyName]]) {
                NSLog(matchingFailureReason, propertyName);
                return NO;
            }
        }
    }

    if (self.anonymous != [dictionary[kUserPropertyNameAnonymous] boolValue]) {
        NSLog(matchingFailureReason, kUserPropertyNameAnonymous);
        return NO;
    }

    if (includeConfig && ![self.config.featuresJsonDictionary isEqual:dictionary[kUserPropertyNameConfig]]) {
        NSLog(matchingFailureReason, kUserPropertyNameConfig);
        return NO;
    }

    if (!includePrivate && privateProperties.count && ![dictionary[kUserPropertyNamePrivateAttributes] isEqual:privateProperties]) {
        NSLog(matchingFailureReason, kUserPropertyNamePrivateAttributes);
        return NO;
    }

    return YES;
}

-(id)propertyForName:(NSString*)name {
    NSDictionary *propertyMap = @{kUserPropertyNameKey: self.key, kUserPropertyNameIp: self.ip, kUserPropertyNameCountry: self.country, kUserPropertyNameName: self.name, kUserPropertyNameFirstName: self.firstName, kUserPropertyNameLastName: self.lastName, kUserPropertyNameEmail: self.email, kUserPropertyNameAvatar: self.avatar, kUserPropertyNameCustom: self.custom, kUserPropertyNameUpdatedAt: self.updatedAt, kUserPropertyNameConfig: self.config, kUserPropertyNameAnonymous: @(self.anonymous), kUserPropertyNameDevice: self.device, kUserPropertyNameOs: self.os};

    return propertyMap[name];
}
@end

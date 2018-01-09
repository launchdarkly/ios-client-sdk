//
//  LDUserModel+Equatable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDUserModel+Equatable.h"
#import "LDUserModel+Testable.h"
#import "NSDictionary+StringKey_Matchable.h"
#import "NSDateFormatter+LDUserModel.h"

@implementation LDUserModel (Equatable)
-(BOOL) isEqual:(id)object ignoringAttributes:(NSArray<NSString*>*)ignoredAttributes {
    LDUserModel *otherUser = (LDUserModel*)object;
    if (otherUser == nil) {
        return NO;
    }
    NSDictionary *dictionary = [self dictionaryValueWithFlags:YES includePrivateAttributes:YES privateAttributesFromConfig:nil includePrivateAttributeList:YES];
    NSDictionary *otherDictionary = [otherUser dictionaryValueWithFlags:YES includePrivateAttributes:YES privateAttributesFromConfig:nil includePrivateAttributeList:YES];
    NSArray *differingKeys = [dictionary keysWithDifferentValuesIn: otherDictionary ignoringKeys: ignoredAttributes];
    return (differingKeys == nil || [differingKeys count] == 0);
}

-(BOOL)matchesDictionary:(NSDictionary *)dictionary includeFlags:(BOOL)includeConfig includePrivateAttributes:(BOOL)includePrivate privateAttributes:(NSArray<NSString*> *)privateAttributes {
    NSString *matchingFailureReason = @"Dictionary value does not match LDUserModel property: %@";
    NSString *containsFailureReason = @"Dictionary contains private property: %@";

    if (![self.key isEqualToString:dictionary[kUserAttributeKey]]) {
        NSLog(matchingFailureReason, kUserAttributeKey);
        return NO;
    }

    NSArray<NSString *> *stringAttributes = @[kUserAttributeIp, kUserAttributeCountry, kUserAttributeName, kUserAttributeFirstName, kUserAttributeLastName, kUserAttributeEmail, kUserAttributeAvatar];
    for (NSString *attribute in stringAttributes) {
        if (!includePrivate && [privateAttributes containsObject:attribute]) {
            if (dictionary[attribute] != nil) {
                NSLog(@"Dictionary contains property %@", attribute);
                return NO;
            }
            continue;
        }
        if (![[self propertyForAttribute:attribute] isEqualToString:dictionary[attribute]]) {
            NSLog(matchingFailureReason, attribute);
            return NO;
        }
    }

    if (![[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] isEqualToString:dictionary[kUserAttributeUpdatedAt]]) {
        NSLog(matchingFailureReason, kUserAttributeUpdatedAt);
        return NO;
    }

    if (!includePrivate && [privateAttributes containsObject:kUserAttributeCustom]) {
        if (dictionary[kUserAttributeCustom] != nil) {
            NSLog(containsFailureReason, kUserAttributeCustom);
            return NO;
        }
    } else {
        NSDictionary *customDictionary = dictionary[kUserAttributeCustom];

        for (NSString *customAttribute in self.custom.allKeys) {
            if (!includePrivate && [privateAttributes containsObject:customAttribute]) {
                if (customDictionary[customAttribute] != nil) {
                    NSLog(containsFailureReason, customAttribute);
                    return NO;
                }
                continue;
            }

            //NOTE: The stubbed custom dictionary only contains string values...
            if ([self.custom[customAttribute] isKindOfClass:[NSString class]] && ![self.custom[customAttribute] isEqualToString:customDictionary[customAttribute]]) {
                NSLog(containsFailureReason, customAttribute);
                return NO;
            }
            if (![self.custom[customAttribute] isKindOfClass:[NSString class]]) { NSLog(@"WARNING: Non-string type contained in LDUserModel.custom at the key %@", customAttribute); }
        }

        NSArray<NSString *> *customStringAttributes = @[kUserAttributeDevice, kUserAttributeOs];
        for (NSString *attribute in customStringAttributes) {
            if ([self propertyForAttribute:attribute] == nil) { continue; }
            if (!includePrivate && [privateAttributes containsObject:attribute]) {
                if (customDictionary[attribute] != nil) {
                    NSLog(containsFailureReason, attribute);
                    return NO;
                }
                continue;
            }
            if (![[self propertyForAttribute:attribute] isEqualToString:customDictionary[attribute]]) {
                NSLog(matchingFailureReason, attribute);
                return NO;
            }
        }
    }

    if (self.anonymous != [dictionary[kUserAttributeAnonymous] boolValue]) {
        NSLog(matchingFailureReason, kUserAttributeAnonymous);
        return NO;
    }

    if (includeConfig && ![self.config.featuresJsonDictionary isEqual:dictionary[kUserAttributeConfig]]) {
        NSLog(matchingFailureReason, kUserAttributeConfig);
        return NO;
    }

    if (!includePrivate && privateAttributes.count && ![dictionary[kUserAttributePrivateAttributes] isEqual:privateAttributes]) {
        NSLog(matchingFailureReason, kUserAttributePrivateAttributes);
        return NO;
    }

    return YES;
}

-(id)propertyForAttribute:(NSString*)attribute {
    NSDictionary *propertyMap = @{kUserAttributeKey: self.key, kUserAttributeIp: self.ip, kUserAttributeCountry: self.country, kUserAttributeName: self.name, kUserAttributeFirstName: self.firstName, kUserAttributeLastName: self.lastName, kUserAttributeEmail: self.email, kUserAttributeAvatar: self.avatar, kUserAttributeCustom: self.custom, kUserAttributeUpdatedAt: self.updatedAt, kUserAttributeConfig: self.config, kUserAttributeAnonymous: @(self.anonymous), kUserAttributeDevice: self.device, kUserAttributeOs: self.os};

    return propertyMap[attribute];
}
@end

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
    NSDictionary *dictionary = [self dictionaryValueWithFlags:YES includePrivateAttributes:YES config:nil includePrivateAttributeList:YES];
    NSDictionary *otherDictionary = [otherUser dictionaryValueWithFlags:YES includePrivateAttributes:YES config:nil includePrivateAttributeList:YES];
    NSArray *differingKeys = [dictionary keysWithDifferentValuesIn: otherDictionary ignoringKeys: ignoredAttributes];
    return (differingKeys == nil || [differingKeys count] == 0);
}

-(BOOL)matchesDictionary:(NSDictionary *)dictionary includeFlags:(BOOL)includeConfig includePrivateAttributes:(BOOL)includePrivate privateAttributes:(NSArray<NSString*> *)privateAttributes {
    NSString *matchingFailureReason = @"Dictionary value does not match LDUserModel attribute: %@";
    NSString *dictionaryContainsAttributeFailureReason = @"Dictionary contains private attribute: %@";
    NSString *privateAttributeListContainsFailureReason = @"Private Attributes List contains private attribute: %@";
    NSString *privateAttributeListDoesNotContainFailureReason = @"Private Attributes List does not contain private attribute: %@";

    if (![self.key isEqualToString:dictionary[kUserAttributeKey]]) {
        NSLog(matchingFailureReason, kUserAttributeKey);
        return NO;
    }

    NSArray<NSString *> *stringAttributes = @[kUserAttributeIp, kUserAttributeCountry, kUserAttributeName, kUserAttributeFirstName, kUserAttributeLastName, kUserAttributeEmail, kUserAttributeAvatar];
    for (NSString *attribute in stringAttributes) {
        if (!includePrivate && [privateAttributes containsObject:attribute]) {
            if (dictionary[attribute] != nil) {
                NSLog(@"Dictionary contains attribute %@", attribute);
                return NO;
            }
            continue;
        }
        id property = [self propertyForAttribute:attribute];
        NSString *dictionaryAttribute = dictionary[attribute];
        if (!property && !dictionaryAttribute) { continue; }
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
            NSMutableDictionary *customDictionary = [dictionary[kUserAttributeCustom] mutableCopy];

            for (NSString *attribute in @[kUserAttributeDevice, kUserAttributeOs]) {
                id property = [self propertyForAttribute:attribute];
                NSString *dictionaryAttribute = customDictionary[attribute];
                if (property && ![property isEqualToString:dictionaryAttribute]) {
                    NSLog(matchingFailureReason, attribute);
                    return NO;
                }
            }

            [customDictionary removeObjectsForKeys:@[kUserAttributeDevice, kUserAttributeOs]];

            if (customDictionary.count > 0) {
                NSLog(dictionaryContainsAttributeFailureReason, kUserAttributeCustom);
                return NO;
            }
        }
    } else {
        NSDictionary *customDictionary = dictionary[kUserAttributeCustom];

        for (NSString *customAttribute in self.custom.allKeys) {
            if (!includePrivate && [privateAttributes containsObject:customAttribute]) {
                if (customDictionary[customAttribute] != nil) {
                    NSLog(dictionaryContainsAttributeFailureReason, customAttribute);
                    return NO;
                }
                continue;
            }

            //NOTE: The stubbed custom dictionary only contains string values...
            if ([self.custom[customAttribute] isKindOfClass:[NSString class]] && ![self.custom[customAttribute] isEqualToString:customDictionary[customAttribute]]) {
                NSLog(dictionaryContainsAttributeFailureReason, customAttribute);
                return NO;
            }
            if (![self.custom[customAttribute] isKindOfClass:[NSString class]]) { NSLog(@"WARNING: Non-string type contained in LDUserModel.custom at the key %@", customAttribute); }
        }

        for (NSString *attribute in @[kUserAttributeDevice, kUserAttributeOs]) {
            if ([self propertyForAttribute:attribute] == nil) { continue; }
            if (!includePrivate && [privateAttributes containsObject:attribute]) {
                if (customDictionary[attribute] != nil) {
                    NSLog(dictionaryContainsAttributeFailureReason, attribute);
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

    NSDictionary *dictionaryConfig = dictionary[kUserAttributeConfig];
    if (includeConfig) {
        NSDictionary *config = [self.config dictionaryValueIncludeNulls:NO];
        if ( (config && ![config isEqual:dictionaryConfig]) || (!config && dictionaryConfig) ) {
            NSLog(matchingFailureReason, kUserAttributeConfig);
            return NO;
        }
    } else {
        if (dictionaryConfig) {
            NSLog(matchingFailureReason, kUserAttributeConfig);
            return NO;
        }
    }

    NSArray<NSString *> *privateAttributeList = dictionary[kUserAttributePrivateAttributes];
    if (includePrivate) {
        if (privateAttributeList) {
            NSLog(dictionaryContainsAttributeFailureReason, kUserAttributePrivateAttributes);
            return NO;
        }
    } else {
        // !includePrivate
        if (privateAttributeList && privateAttributeList.count == 0) {
            NSLog(dictionaryContainsAttributeFailureReason, kUserAttributePrivateAttributes);
            return NO;
        }
        for (NSString *attribute in privateAttributes) {
            id property = [self propertyForAttribute:attribute];
            if ([attribute isEqualToString:kUserAttributeCustom]) {
                //Specialized handling because the dictionary can exist with ONLY the device & os, but no other keys
                NSMutableDictionary *customProperty = [property mutableCopy];
                [customProperty removeObjectsForKeys:@[kUserAttributeDevice, kUserAttributeOs]];
                if (customProperty.count == 0 && [privateAttributeList containsObject:kUserAttributeCustom]) {
                    NSLog(privateAttributeListContainsFailureReason, kUserAttributeCustom);
                    return NO;
                }
                if (customProperty.count > 0 && ![privateAttributeList containsObject:kUserAttributeCustom]) {
                    NSLog(privateAttributeListDoesNotContainFailureReason, kUserAttributeCustom);
                    return NO;
                }
            } else {
                if (!property && [privateAttributeList containsObject:attribute] ) {
                    NSLog(privateAttributeListContainsFailureReason, attribute);
                    return NO;
                }
                if (property && ![privateAttributeList containsObject:attribute]) {
                    NSLog(privateAttributeListDoesNotContainFailureReason, attribute);
                    return NO;
                }
            }
        }
    }

    return YES;
}

-(id)propertyForAttribute:(NSString*)attribute {
    NSArray *attributeList = @[kUserAttributeKey, kUserAttributeIp, kUserAttributeCountry, kUserAttributeName, kUserAttributeFirstName, kUserAttributeLastName, kUserAttributeEmail, kUserAttributeAvatar, kUserAttributeCustom, kUserAttributeUpdatedAt, kUserAttributeConfig, kUserAttributeAnonymous, kUserAttributeDevice, kUserAttributeOs];
    NSUInteger attributeIndex = [attributeList indexOfObject:attribute];
    if (attributeIndex != NSNotFound) {
        switch (attributeIndex) {
            case 0: return self.key;
            case 1: return self.ip;
            case 2: return self.country;
            case 3: return self.name;
            case 4: return self.firstName;
            case 5: return self.lastName;
            case 6: return self.email;
            case 7: return self.avatar;
            case 8: return self.custom;
            case 9: return self.updatedAt;
            case 10: return self.config;
            case 11: return @(self.anonymous);
            case 12: return self.device;
            case 13: return self.os;
        }
    }

    return self.custom[attribute];
}
@end

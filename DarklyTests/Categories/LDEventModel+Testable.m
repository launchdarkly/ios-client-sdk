//
//  LDEventModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventModel+Testable.h"
#import "LDEventModel.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDUserModel+Testable.h"
#import "NSInteger+Testable.h"
#import "LDFlagConfigTracker+Testable.h"

extern NSString * const kEventModelKindFeature;
extern NSString * const kEventModelKindCustom;
extern NSString * const kEventModelKindIdentify;
extern NSString * const kEventModelKindFeatureSummary;
extern NSString * const kEventModelKindDebug;

extern NSString * const kEventModelKeyKey;
extern NSString * const kEventModelKeyKind;
extern NSString * const kEventModelKeyCreationDate;
extern NSString * const kEventModelKeyData;
extern NSString * const kEventModelKeyFlagConfigValue;
extern NSString * const kEventModelKeyValue;
extern NSString * const kEventModelKeyVersion;
extern NSString * const kEventModelKeyVariation;
extern NSString * const kEventModelKeyIsDefault;
extern NSString * const kEventModelKeyDefault;
extern NSString * const kEventModelKeyUser;
extern NSString * const kEventModelKeyUserKey;
extern NSString * const kEventModelKeyInlineUser;
extern NSString * const kEventModelKeyStartDate;
extern NSString * const kEventModelKeyEndDate;
extern NSString * const kEventModelKeyFeatures;

extern NSString * const kLDFlagKeyIsADouble;

NSString * const kFeatureEventKeyStub = @"LDEventModel.featureEvent.key";
NSString * const kCustomEventKeyStub = @"LDEventModel.customEvent.key";
NSString * const kDebugEventKeyStub = @"LDEventModel.debugEvent.key";
NSString * const kCustomEventCustomDataKeyStub = @"LDEventModel.customEventCustomData.key";
NSString * const kCustomEventCustomDataValueStub = @"LDEventModel.customEventCustomData.value";
const double featureEventValueStub = 3.14159;
const double featureEventDefaultValueStub = 2.71828;

@implementation LDEventModel (Testable)
+(NSArray<NSString*>*)allEventKinds {
    return @[kEventModelKindFeature, kEventModelKindCustom, kEventModelKindIdentify, kEventModelKindFeatureSummary, kEventModelKindDebug];
}

+(NSArray<NSString*>*)eventKindsWithCommonFields {
    return @[kEventModelKindFeature, kEventModelKindCustom, kEventModelKindIdentify, kEventModelKindDebug];
}

-(BOOL)hasCommonFields {
    return [[LDEventModel eventKindsWithCommonFields] containsObject:self.kind];
}

+(NSArray<NSString*>*)eventKindsForFlagRequests {
    return @[kEventModelKindFeature, kEventModelKindDebug];
}

-(BOOL)isFlagRequestEventKind {
    return [[LDEventModel eventKindsForFlagRequests] containsObject:self.kind];
}

+(NSArray<NSString*>*)eventKindsThatAlwaysInlineUsers {
    return @[kEventModelKindIdentify, kEventModelKindDebug];
}

-(BOOL)alwaysInlinesUser {
    return [[LDEventModel eventKindsThatAlwaysInlineUsers] containsObject:self.kind];
}

+(instancetype)stubEventWithKind:(NSString*)eventKind user:(nullable LDUserModel*)user config:(nullable LDConfig*)config {
    if (!user) {
        user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    }
    BOOL inlineUser = config ? config.inlineUserInEvents : false;
    if ([eventKind isEqualToString:kEventModelKindFeature]) {
        LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"doubleConfigIsADouble-Pi-withVersion" flagKey:kLDFlagKeyIsADouble];
        return [LDEventModel featureEventWithFlagKey:kFeatureEventKeyStub
                                     flagConfigValue:flagConfigValue
                                    defaultFlagValue:@(featureEventDefaultValueStub)
                                                user:user
                                          inlineUser:inlineUser];
    }
    if ([eventKind isEqualToString:kEventModelKindCustom]) {
        return [LDEventModel customEventWithKey:kCustomEventKeyStub
                              customData:@{kCustomEventCustomDataKeyStub: kCustomEventCustomDataValueStub}
                                      userValue:user
                                     inlineUser:inlineUser];
    }
    if ([eventKind isEqualToString:kEventModelKindFeatureSummary]) {
        return [LDEventModel summaryEventWithTracker:[LDFlagConfigTracker stubTracker]];
    }
    if ([eventKind isEqualToString:kEventModelKindDebug]) {
        LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"doubleConfigIsADouble-Pi-withVersion" flagKey:kLDFlagKeyIsADouble];
        return [LDEventModel debugEventWithFlagKey:kDebugEventKeyStub flagConfigValue:flagConfigValue defaultFlagValue:@(featureEventDefaultValueStub) user:user];
    }

    return [LDEventModel identifyEventWithUser:user];
}

+(nonnull NSArray<NSDictionary*>*)stubEventDictionariesForUser:(nullable LDUserModel*)user config:(nullable LDConfig*)config {
    NSDictionary *featureEventDictionary = [[LDEventModel stubEventWithKind:kEventModelKindFeature user:user config:config] dictionaryValueUsingConfig:config];
    NSDictionary *customEventDictionary = [[LDEventModel stubEventWithKind:kEventModelKindCustom user:user config:config] dictionaryValueUsingConfig:config];
    NSDictionary *identifyEventDictionary = [[LDEventModel stubEventWithKind:kEventModelKindIdentify user:user config:config] dictionaryValueUsingConfig:config];
    NSDictionary *summaryEventDictionary = [[LDEventModel summaryEventWithTracker:[LDFlagConfigTracker stubTracker]] dictionaryValueUsingConfig:config];
    NSDictionary *debugEventDictionary = [[LDEventModel stubEventWithKind:kEventModelKindDebug user:user config:config] dictionaryValueUsingConfig:config];
    return @[featureEventDictionary, customEventDictionary, identifyEventDictionary, summaryEventDictionary, debugEventDictionary];
}

-(BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[LDEventModel class]]) {
        NSLog(@"[%@ %@]: object is not class %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), NSStringFromClass([self class]));
        return NO;
    }
    LDEventModel *otherEvent = object;

    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];
    if (![self.kind isEqualToString:otherEvent.kind]) {
        [mismatchedProperties addObject:kEventModelKeyKind];
    }

    if (self.hasCommonFields) {
        if (![self.key isEqualToString:otherEvent.key]) {
            [mismatchedProperties addObject:kEventModelKeyKey];
        }
        if (self.inlineUser != otherEvent.inlineUser) {
            [mismatchedProperties addObject:kEventModelKeyInlineUser];
        }
        if (self.inlineUser) {
            if (![self.user isEqual:otherEvent.user ignoringAttributes:@[kUserAttributeConfig]]) {
                [mismatchedProperties addObject:kEventModelKeyUser];
            }
        } else {
            if (![self.user.key isEqualToString:otherEvent.user.key]) {
                [mismatchedProperties addObject:kEventModelKeyUserKey];
            }
        }
        if (self.creationDate != otherEvent.creationDate) {
            [mismatchedProperties addObject:kEventModelKeyCreationDate];
        }
    }

    if (self.isFlagRequestEventKind) {
        if (![self.flagConfigValue isEqual:otherEvent.flagConfigValue]) {
            [mismatchedProperties addObject:kEventModelKeyFlagConfigValue];
        }
        if (![self.defaultValue isEqual:otherEvent.defaultValue]) {
            [mismatchedProperties addObject:kEventModelKeyDefault];
        }
    }

    if ([self.kind isEqualToString:kEventModelKindCustom]) {
        if (![self.data isEqual:otherEvent.data]) {
            [mismatchedProperties addObject:kEventModelKeyData];
        }
    }

    if ([self.kind isEqualToString:kEventModelKindFeatureSummary]) {
        if (self.startDateMillis != otherEvent.startDateMillis) {
            [mismatchedProperties addObject:kEventModelKeyStartDate];
        }
        if (!Approximately(self.endDateMillis, otherEvent.endDateMillis, 10)) {
            [mismatchedProperties addObject:kEventModelKeyEndDate];
        }
        if (![self.flagRequestSummary isEqualToDictionary:otherEvent.flagRequestSummary]) {
            [mismatchedProperties addObject:kEventModelKeyFeatures];
        }
    }

    //identify events have only the fields common to all events

    if (mismatchedProperties.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }

    return YES;
}

-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary {
    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];

    if (![self.kind isEqualToString:dictionary[kEventModelKeyKind]]) {
        [mismatchedProperties addObject:kEventModelKeyKind];
    }
    if (self.hasCommonFields) {
        if (![self.key isEqualToString:dictionary[kEventModelKeyKey]]) {
            [mismatchedProperties addObject:kEventModelKeyKey];
        }
        if (self.inlineUser) {
            if (![self.user.key isEqualToString:dictionary[kEventModelKeyUser][kUserAttributeKey]]) {
                [mismatchedProperties addObject:kEventModelKeyUser];
            }
        } else {
            if (![self.user.key isEqualToString:dictionary[kEventModelKeyUserKey]]) {
                [mismatchedProperties addObject:kEventModelKeyUserKey];
            }
        }
        //If the event and dictionary have creation dates within 1 millisecond, that's close enough...
        if (!Approximately(self.creationDate, [dictionary[kEventModelKeyCreationDate] integerValue], 1)) {
            [mismatchedProperties addObject:kEventModelKeyCreationDate];
        }
    }

    if (self.isFlagRequestEventKind) {
        if (self.flagConfigValue) {
            if (![self.flagConfigValue hasPropertiesMatchingDictionary:dictionary]) {
                [mismatchedProperties addObject:kEventModelKeyFlagConfigValue];
            }
        } else {
            if (!dictionary[kEventModelKeyValue] || (dictionary[kEventModelKeyValue] && ![dictionary[kEventModelKeyValue] isEqual:self.defaultValue])) {
                [mismatchedProperties addObject:kEventModelKeyFlagConfigValue];
            }
            if (dictionary[kEventModelKeyVersion] || dictionary[kEventModelKeyVariation]) {
                [mismatchedProperties addObject:kEventModelKeyFlagConfigValue];
            }
        }
        if (![self.defaultValue isEqual:dictionary[kEventModelKeyDefault]]) {
            [mismatchedProperties addObject:kEventModelKeyDefault];
        }
    }

    if ([self.kind isEqualToString:kEventModelKindCustom]) {
        if (![self.data isEqual:dictionary[kEventModelKeyData]]) {
            [mismatchedProperties addObject:kEventModelKeyData];
        }
    }

    if ([self.kind isEqualToString:kEventModelKindFeatureSummary]) {
        if (self.startDateMillis != [dictionary[kEventModelKeyStartDate] integerValue]) {
            [mismatchedProperties addObject:kEventModelKeyStartDate];
        }
        if (!Approximately(self.endDateMillis, [dictionary[kEventModelKeyEndDate] integerValue], 10)) {
            [mismatchedProperties addObject:kEventModelKeyEndDate];
        }
        if (![self.flagRequestSummary isEqualToDictionary:dictionary[kEventModelKeyFeatures]]) {
            [mismatchedProperties addObject:kEventModelKeyFeatures];
        }
    }

    //identify events have only the fields common to all events

    if (mismatchedProperties.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }

    return YES;
}

//This is only built for Feature and Debug events...open for modification to handle the others when needed
-(BOOL)hasPropertiesMatchingFlagKey:(NSString*)flagKey
                          eventKind:(NSString*)eventKind
                    flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                   defaultFlagValue:(id)defaultFlagValue
                               user:(LDUserModel*)user
                         inlineUser:(BOOL)inlineUser
                 creationDateMillis:(NSInteger)creationDateMillis {
    NSMutableArray<NSString*> *mismatchedProperties = [NSMutableArray array];

    if (![self.key isEqualToString:flagKey]) {
        [mismatchedProperties addObject:kEventModelKeyKey];
    }
    if (![self.kind isEqualToString:eventKind]) {
        [mismatchedProperties addObject:kEventModelKeyKind];
    }
    if (![self.flagConfigValue isEqual:flagConfigValue]) {
        [mismatchedProperties addObject:kEventModelKeyValue];
    }
    if (![self.defaultValue isEqual:defaultFlagValue]) {
        [mismatchedProperties addObject:kEventModelKeyDefault];
    }
    if (![self.user isEqual:user ignoringAttributes:@[]]) {
        [mismatchedProperties addObject:kEventModelKeyUser];
    }
    if (self.inlineUser != inlineUser) {
        [mismatchedProperties addObject:kEventModelKeyInlineUser];
    }
    if (!Approximately(self.creationDate, creationDateMillis, 10)) {
        [mismatchedProperties addObject:kEventModelKeyCreationDate];
    }

    if (mismatchedProperties.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedProperties componentsJoinedByString:@", "]);
        return NO;
    }
    return YES;
}

@end

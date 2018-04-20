//
//  LDEventModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDEventModel.h"
#import "LDUserModel.h"
#import "NSDate+ReferencedDate.h"
#import "LDFlagConfigTracker.h"

NSString * const kEventModelKindFeature = @"feature";
NSString * const kEventModelKindCustom = @"custom";
NSString * const kEventModelKindIdentify = @"identify";
NSString * const kEventModelKindFeatureSummary = @"flag";
NSString * const kEventModelKindDebug = @"debug";

NSString * const kEventModelKeyKey = @"key";
NSString * const kEventModelKeyKind = @"kind";
NSString * const kEventModelKeyCreationDate = @"creationDate";
NSString * const kEventModelKeyData = @"data";
NSString * const kEventModelKeyValue = @"value";
NSString * const kEventModelKeyIsDefault = @"isDefault";
NSString * const kEventModelKeyDefault = @"default";
NSString * const kEventModelKeyUser = @"user";
NSString * const kEventModelKeyUserKey = @"userKey";
NSString * const kEventModelKeyInlineUser = @"inlineUser";
NSString * const kEventModelKeyStartDate = @"startDate";
NSString * const kEventModelKeyEndDate = @"endDate";
NSString * const kEventModelKeyFeatures = @"features";

@implementation LDEventModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.key forKey:kEventModelKeyKey];
    [encoder encodeObject:self.kind forKey:kEventModelKeyKind];
    [encoder encodeInteger:self.creationDate forKey:kEventModelKeyCreationDate];
    [encoder encodeObject:self.data forKey:kEventModelKeyData];
    [encoder encodeObject:self.value forKey:kEventModelKeyValue];
    [encoder encodeObject:self.defaultValue forKey:kEventModelKeyDefault];
    [encoder encodeObject:self.user forKey:kEventModelKeyUser];
    [encoder encodeBool:self.inlineUser forKey:kEventModelKeyInlineUser];
    [encoder encodeInteger:self.startDateMillis forKey:kEventModelKeyStartDate];
    [encoder encodeInteger:self.endDateMillis forKey:kEventModelKeyEndDate];
    [encoder encodeObject:self.flagRequestSummary forKey:kEventModelKeyFeatures];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if(!(self = [super init])) { return nil; }

    self.key = [decoder decodeObjectForKey:kEventModelKeyKey];
    self.kind = [decoder decodeObjectForKey:kEventModelKeyKind];
    self.creationDate = [decoder decodeIntegerForKey:kEventModelKeyCreationDate];
    self.data = [decoder decodeObjectForKey:kEventModelKeyData];
    self.value = [decoder decodeObjectForKey:kEventModelKeyValue];
    self.defaultValue = [decoder decodeObjectForKey:kEventModelKeyDefault];
    if (!self.defaultValue) {
        self.defaultValue = [decoder decodeObjectForKey:kEventModelKeyIsDefault];
    }
    self.user = [decoder decodeObjectForKey:kEventModelKeyUser];
    self.inlineUser = [decoder decodeBoolForKey:kEventModelKeyInlineUser];
    self.startDateMillis = [decoder decodeIntegerForKey:kEventModelKeyStartDate];
    self.endDateMillis = [decoder decodeIntegerForKey:kEventModelKeyEndDate];
    self.flagRequestSummary = [decoder decodeObjectForKey:kEventModelKeyFeatures];

    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if(!(self = [super init])) { return nil; }

    self.kind = dictionary[kEventModelKeyKind];

    //common for feature, custom, & identify events
    self.key = dictionary[kEventModelKeyKey];
    self.inlineUser = [dictionary.allKeys containsObject:kEventModelKeyUser];
    if (self.inlineUser) {
        self.user = [[LDUserModel alloc] initWithDictionary:dictionary[kEventModelKeyUser]];
    } else {
        self.user = [[LDUserModel alloc] init];
        self.user.key = dictionary[kEventModelKeyUserKey];
    }
    self.creationDate = [dictionary[kEventModelKeyCreationDate] longValue];
    if (self.creationDate == 0) {
        self.creationDate = [[NSDate date] millisSince1970];
    }

    //feature events
    self.value = dictionary[kEventModelKeyValue];
    self.defaultValue = dictionary[kEventModelKeyDefault];

    //custom events
    self.data = dictionary[kEventModelKeyData];

    //featureSummary events
    self.startDateMillis = [dictionary[kEventModelKeyStartDate] integerValue];
    self.endDateMillis = [dictionary[kEventModelKeyEndDate] integerValue];
    self.flagRequestSummary = dictionary[kEventModelKeyFeatures];

    return self;
}

+(instancetype)featureEventWithFlagKey:(NSString*)flagKey
                             flagValue:(NSObject*)flagValue
                      defaultFlagValue:(NSObject*)defaultFlagValue
                             userValue:(LDUserModel*)userValue
                            inlineUser:(BOOL)inlineUser {
    return [[LDEventModel alloc] initFeatureEventWithFlagKey:flagKey flagValue:flagValue defaultFlagValue:defaultFlagValue userValue:userValue inlineUser:inlineUser];
}

-(instancetype)initFeatureEventWithFlagKey:(NSString*)flagKey
                                 flagValue:(NSObject*)flagValue
                          defaultFlagValue:(NSObject*)defaultFlagValue
                                 userValue:(LDUserModel*)userValue
                                inlineUser:(BOOL)inlineUser {
    if (!(self = [self init])) { return nil; }

    self.key = flagKey;
    self.kind = kEventModelKindFeature;
    self.value = flagValue;
    self.defaultValue = defaultFlagValue;
    self.user = userValue;
    self.inlineUser = inlineUser;

    return self;
}

+(instancetype)customEventWithKey:(NSString*)featureKey
                       customData:(NSDictionary*)customData
                        userValue:(LDUserModel*)userValue
                       inlineUser:(BOOL)inlineUser {
    return [[LDEventModel alloc] initCustomEventWithKey:featureKey customData:customData userValue:userValue inlineUser:inlineUser];
}

-(instancetype)initCustomEventWithKey:(NSString*)featureKey
                           customData:(NSDictionary*)customData
                            userValue:(LDUserModel*)userValue
                           inlineUser:(BOOL)inlineUser {
    if(!(self = [self init])) { return nil; }

    self.key = featureKey;
    self.kind = kEventModelKindCustom;
    self.data = customData;
    self.user = userValue;
    self.inlineUser = inlineUser;

    return self;
}

+(instancetype)identifyEventWithUser:(LDUserModel*)user {
    return [[LDEventModel alloc] initIdentifyEventWithUser:user];
}

-(instancetype)initIdentifyEventWithUser:(LDUserModel*)user {
    if(!(self = [self init])) { return nil; }

    self.key = user.key;
    self.kind = kEventModelKindIdentify;
    self.user = user;
    self.inlineUser = YES;

    return self;
}

+(instancetype)summaryEventWithTracker:(LDFlagConfigTracker*)tracker {
    return [[LDEventModel alloc] initSummaryEventWithTracker:tracker];
}

-(instancetype)initSummaryEventWithTracker:(LDFlagConfigTracker*)tracker {
    if(!(self = [self init])) { return nil; }

    self.kind = kEventModelKindFeatureSummary;
    self.startDateMillis = tracker.startDateMillis;
    self.endDateMillis = [[NSDate date] millisSince1970];
    NSMutableDictionary *flagRequestSummary = [NSMutableDictionary dictionaryWithCapacity:tracker.flagCounters.count];
    for (NSString *flagKey in [tracker.flagCounters.allKeys copy]) {
        flagRequestSummary[flagKey] = [tracker.flagCounters[flagKey] dictionaryValue];
    }
    self.flagRequestSummary = [NSDictionary dictionaryWithDictionary:flagRequestSummary];

    return self;
}

+(instancetype)debugEventWithFlagKey:(NSString *)flagKey flagValue:(NSObject*)flagValue defaultFlagValue:(NSObject*)defaultflagValue userValue:(LDUserModel*)userValue {
    return [[LDEventModel alloc] initDebugEventWithFlagKey:flagKey flagValue:flagValue defaultFlagValue:defaultflagValue userValue:userValue];
}

-(instancetype)initDebugEventWithFlagKey:(NSString*)flagKey  flagValue:(NSObject*)flagValue defaultFlagValue:(NSObject*)defaultflagValue userValue:(LDUserModel*)userValue {
    self = [self initFeatureEventWithFlagKey:flagKey flagValue:flagValue defaultFlagValue:defaultflagValue userValue:userValue inlineUser:YES];
    self.kind = kEventModelKindDebug;

    return self;
}

-(instancetype)init {
    self = [super init];
    
    if(self != nil) {
        // Need to set creationDate
        self.creationDate = [[NSDate date] millisSince1970];
    }
    
    return self;
}


-(NSDictionary *)dictionaryValueUsingConfig:(LDConfig*)config {
    if ([self.kind isEqualToString:kEventModelKindFeatureSummary]) {
        return [self featuresSummaryDictionaryValue];
    }

    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    if (self.key) {
        dictionary[kEventModelKeyKey] = self.key;
    }
    if (self.kind) {
        dictionary[kEventModelKeyKind] = self.kind;
    }
    if (self.creationDate) {
        dictionary[kEventModelKeyCreationDate] = @(self.creationDate);
    }
    if (self.data) {
        dictionary[kEventModelKeyData] = self.data;
    }
    if (self.value) {
        dictionary[kEventModelKeyValue] = self.value;
    }
    if (self.defaultValue) {
        dictionary[kEventModelKeyDefault] = self.defaultValue;
    }
    if (self.user) {
        if (self.inlineUser || [self.kind isEqualToString:kEventModelKindIdentify]) {
            dictionary[kEventModelKeyUser] = [self.user dictionaryValueWithFlagConfig:NO includePrivateAttributes:NO config:config];
        } else {
            dictionary[kEventModelKeyUserKey] = self.user.key;
        }
    }

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

-(NSDictionary*)featuresSummaryDictionaryValue; {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    if (self.kind) {
        dictionary[kEventModelKeyKind] = self.kind;
    }
    dictionary[kEventModelKeyStartDate] = @(self.startDateMillis);
    dictionary[kEventModelKeyEndDate] = @(self.endDateMillis);
    dictionary[kEventModelKeyFeatures] = self.flagRequestSummary;

    return [NSDictionary dictionaryWithDictionary:dictionary];
}

@end

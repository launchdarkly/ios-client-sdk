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
#import "LDFlagConfigValue.h"
#import "LDFlagConfigTracker.h"
#import "LDFlagCounter.h"

NSString * const kEventModelKindFeature = @"feature";
NSString * const kEventModelKindCustom = @"custom";
NSString * const kEventModelKindIdentify = @"identify";
NSString * const kEventModelKindFeatureSummary = @"summary";
NSString * const kEventModelKindDebug = @"debug";

NSString * const kEventModelKeyKey = @"key";
NSString * const kEventModelKeyKind = @"kind";
NSString * const kEventModelKeyCreationDate = @"creationDate";
NSString * const kEventModelKeyData = @"data";
NSString * const kEventModelKeyFlagConfigValue = @"flagConfigValue";
NSString * const kEventModelKeyValue = @"value";
NSString * const kEventModelKeyVersion = @"version";
NSString * const kEventModelKeyVariation = @"variation";
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
    [encoder encodeInt64:self.creationDate forKey:kEventModelKeyCreationDate];
    [encoder encodeObject:self.data forKey:kEventModelKeyData];
    [encoder encodeObject:self.flagConfigValue forKey:kEventModelKeyFlagConfigValue];
    [encoder encodeObject:self.defaultValue forKey:kEventModelKeyDefault];
    [encoder encodeObject:self.user forKey:kEventModelKeyUser];
    [encoder encodeBool:self.inlineUser forKey:kEventModelKeyInlineUser];
    [encoder encodeInt64:self.startDateMillis forKey:kEventModelKeyStartDate];
    [encoder encodeInt64:self.endDateMillis forKey:kEventModelKeyEndDate];
    [encoder encodeObject:self.flagRequestSummary forKey:kEventModelKeyFeatures];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if(!(self = [super init])) { return nil; }

    self.key = [decoder decodeObjectForKey:kEventModelKeyKey];
    self.kind = [decoder decodeObjectForKey:kEventModelKeyKind];
    self.creationDate = [decoder decodeInt64ForKey:kEventModelKeyCreationDate];
    self.data = [decoder decodeObjectForKey:kEventModelKeyData];
    self.flagConfigValue = [decoder decodeObjectForKey:kEventModelKeyFlagConfigValue];
    self.defaultValue = [decoder decodeObjectForKey:kEventModelKeyDefault];
    if (!self.defaultValue) {
        self.defaultValue = [decoder decodeObjectForKey:kEventModelKeyIsDefault];
    }
    self.user = [decoder decodeObjectForKey:kEventModelKeyUser];
    self.inlineUser = [decoder decodeBoolForKey:kEventModelKeyInlineUser];
    self.startDateMillis = [decoder decodeInt64ForKey:kEventModelKeyStartDate];
    self.endDateMillis = [decoder decodeInt64ForKey:kEventModelKeyEndDate];
    self.flagRequestSummary = [decoder decodeObjectForKey:kEventModelKeyFeatures];

    return self;
}

+(instancetype)featureEventWithFlagKey:(NSString*)flagKey
                     reportedFlagValue:(id)reportedFlagValue
                       flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                      defaultFlagValue:(id)defaultFlagValue
                                  user:(LDUserModel*)user
                            inlineUser:(BOOL)inlineUser {
    return [[LDEventModel alloc] initFeatureEventWithFlagKey:flagKey
                                           reportedFlagValue:reportedFlagValue
                                             flagConfigValue:flagConfigValue
                                            defaultFlagValue:defaultFlagValue
                                                        user:user
                                                  inlineUser:inlineUser];
}

-(instancetype)initFeatureEventWithFlagKey:(NSString*)flagKey
                         reportedFlagValue:(id)reportedFlagValue
                           flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                          defaultFlagValue:(id)defaultFlagValue
                                      user:(LDUserModel*)user
                                inlineUser:(BOOL)inlineUser {
    if (!(self = [self init])) { return nil; }

    self.key = flagKey;
    self.kind = kEventModelKindFeature;
    self.reportedValue = reportedFlagValue;
    self.flagConfigValue = flagConfigValue;
    self.defaultValue = defaultFlagValue;
    self.user = user;
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
    if(tracker == nil) { return nil; }

    self.kind = kEventModelKindFeatureSummary;
    self.startDateMillis = tracker.startDateMillis;
    self.endDateMillis = [[NSDate date] millisSince1970];
    self.flagRequestSummary = tracker.flagRequestSummary;

    return self;
}

+(instancetype)debugEventWithFlagKey:(NSString*)flagKey
                   reportedFlagValue:(id)reportedFlagValue
                     flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                    defaultFlagValue:(id)defaultFlagValue
                                user:(LDUserModel*)user {
    return [[LDEventModel alloc] initDebugEventWithFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultFlagValue:defaultFlagValue user:user];
}

-(instancetype)initDebugEventWithFlagKey:(NSString*)flagKey
                       reportedFlagValue:(id)reportedFlagValue
                         flagConfigValue:(LDFlagConfigValue*)flagConfigValue
                        defaultFlagValue:(id)defaultFlagValue
                                    user:(LDUserModel*)user {
    self = [self initFeatureEventWithFlagKey:flagKey reportedFlagValue:reportedFlagValue flagConfigValue:flagConfigValue defaultFlagValue:defaultFlagValue user:user inlineUser:YES];
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
    if ([self.kind isEqualToString:kEventModelKindFeature] || [self.kind isEqualToString:kEventModelKindDebug]) {
        if (self.flagConfigValue) {
            [dictionary addEntriesFromDictionary:[self.flagConfigValue dictionaryValueUseFlagVersionForVersion:YES includeEventTrackingContext:NO]];
        }
        dictionary[kEventModelKeyValue] = self.reportedValue ?: [NSNull null];
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

-(nonnull NSString*)description {
    NSString *details;

    if ([self.kind isEqualToString:kEventModelKindFeature] || [self.kind isEqualToString:kEventModelKindDebug]) {
        details = [NSString stringWithFormat:@"key: %@,\n\treportedFlagValue: %@,\n\tflagConfigValue: %@,\n\tdefaultValue: %@,\n\tuser: %@,\n\tinlineUser: %@, creationDate: %ld",
                   self.key, self.reportedValue ?: @"<null>", self.flagConfigValue ?: @"<null>", self.defaultValue ?: @"<null>", self.user, self.inlineUser ? @"YES" : @"NO", (long)self.creationDate];
    } else if ([self.kind isEqualToString:kEventModelKindCustom]) {
        details = [NSString stringWithFormat:@"key: %@, data: %@, user: %@, inlineUser: %@, creationDate: %ld",
                   self.key, self.data ?: @"<null>", self.user, self.inlineUser ? @"YES" : @"NO", (long)self.creationDate];
    } else if ([self.kind isEqualToString:kEventModelKindIdentify]) {
        details = [NSString stringWithFormat:@"key: %@, user: %@, inlineUser: %@, creationDate: %ld", self.key, self.user, self.inlineUser ? @"YES" : @"NO", (long)self.creationDate];
    } else if ([self.kind isEqualToString:kEventModelKindFeatureSummary]) {
        details = [NSString stringWithFormat:@"startDateMillis: %ld, endDateMillis: %ld, flagRequestSummary: %@", (long)self.startDateMillis, (long)self.endDateMillis, self.flagRequestSummary];
    }

    return [NSString stringWithFormat:@"<LDEventModel: %p, kind: %@, %@>", self, self.kind, details];
}

@end

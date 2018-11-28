//
//  LDUserModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDUserModel.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigTracker.h"
#import "LDUtil.h"
#import "NSDateFormatter+LDUserModel.h"

NSString * const kUserAttributeKey = @"key";
NSString * const kUserAttributeIp = @"ip";
NSString * const kUserAttributeCountry = @"country";
NSString * const kUserAttributeName = @"name";
NSString * const kUserAttributeFirstName = @"firstName";
NSString * const kUserAttributeLastName = @"lastName";
NSString * const kUserAttributeEmail = @"email";
NSString * const kUserAttributeAvatar = @"avatar";
NSString * const kUserAttributeCustom = @"custom";
NSString * const kUserAttributeUpdatedAt = @"updatedAt";
NSString * const kUserAttributeConfig = @"config";
NSString * const kUserAttributeAnonymous = @"anonymous";
NSString * const kUserAttributeDevice = @"device";
NSString * const kUserAttributeOs = @"os";
NSString * const kUserAttributePrivateAttributes = @"privateAttrs";

@interface LDUserModel()
@property (nullable, nonatomic, strong) LDFlagConfigTracker *flagConfigTracker;
@end

@implementation LDUserModel

-(NSDictionary *)dictionaryValueWithPrivateAttributesAndFlagConfig:(BOOL)includeFlags {
    return [self dictionaryValueWithFlagConfig:includeFlags includePrivateAttributes:YES config:nil];
}

-(NSDictionary *)dictionaryValueWithFlagConfig:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate config:(LDConfig*)config {
    NSMutableArray<NSString *> *combinedPrivateAttributes = [NSMutableArray arrayWithArray:self.privateAttributes];
    if (config.privateUserAttributes.count) {
        [combinedPrivateAttributes addObjectsFromArray:config.privateUserAttributes];
    }
    if (config.allUserAttributesPrivate) { combinedPrivateAttributes = [[LDUserModel allUserAttributes] mutableCopy]; }

    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    NSMutableSet *redactedPrivateAttributes = [NSMutableSet set];

    if (self.key) { dictionary[kUserAttributeKey] = self.key; }
    [self storeValue:self.ip in:dictionary forAttribute:kUserAttributeIp includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:self.country in:dictionary forAttribute:kUserAttributeCountry includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:self.name in:dictionary forAttribute:kUserAttributeName includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:self.firstName in:dictionary forAttribute:kUserAttributeFirstName includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:self.lastName in:dictionary forAttribute:kUserAttributeLastName includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:self.email in:dictionary forAttribute:kUserAttributeEmail includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:self.avatar in:dictionary forAttribute:kUserAttributeAvatar includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:@(self.anonymous) in:dictionary forAttribute:kUserAttributeAnonymous includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    [self storeValue:[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] in:dictionary forAttribute:kUserAttributeUpdatedAt includePrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];

    NSDictionary *customDict = [self customDictionaryIncludingPrivate:includePrivate privateAttributes:combinedPrivateAttributes redactedAttributes:redactedPrivateAttributes];
    if (customDict.count > 0) {
        dictionary[kUserAttributeCustom] = customDict;
    }

    if (!includePrivate && redactedPrivateAttributes.count > 0) {
        dictionary[kUserAttributePrivateAttributes] = [redactedPrivateAttributes allObjects];
    }

    if (includeFlags && self.flagConfig.featuresJsonDictionary) {
        dictionary[kUserAttributeConfig] = [self.flagConfig dictionaryValueIncludeNulls:NO];
    }

    return [dictionary copy];
}

- (void)storeValue:(id)value in:(NSMutableDictionary*)dictionary forAttribute:(NSString*)attribute includePrivate:(BOOL)includePrivate privateAttributes:(NSArray<NSString *>*)privateAttributes redactedAttributes:(NSMutableSet<NSString*>*)redactedAttributes {
    if (!value) { return; }
    if (!includePrivate && [privateAttributes containsObject:attribute]) {
        [redactedAttributes addObject:attribute];
        return;
    }
    dictionary[attribute] = value;
}

- (NSDictionary*)customDictionaryIncludingPrivate:(BOOL)includePrivate privateAttributes:(NSArray<NSString *>*)privateAttributes redactedAttributes:(NSMutableSet<NSString*>*)redactedAttributes {
    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:self.custom];
    if (!includePrivate) {
        if (customDict.count > 0 && [privateAttributes containsObject:kUserAttributeCustom]) {
            [customDict removeAllObjects];
            [redactedAttributes addObject:kUserAttributeCustom];
        } else {
            for (NSString *customKey in [self.custom allKeys]) {
                if (self.custom[customKey] && [privateAttributes containsObject:customKey]) {
                    [customDict removeObjectForKey:customKey];
                    [redactedAttributes addObject:customKey];
                }
            }
        }
    }

    if (self.device) { customDict[kUserAttributeDevice] = self.device; }
    if (self.os) { customDict[kUserAttributeOs] = self.os; }
    return [customDict copy];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:kUserAttributeKey];
    [encoder encodeObject:self.ip forKey:kUserAttributeIp];
    [encoder encodeObject:self.country forKey:kUserAttributeCountry];
    [encoder encodeObject:self.name forKey:kUserAttributeName];
    [encoder encodeObject:self.firstName forKey:kUserAttributeFirstName];
    [encoder encodeObject:self.lastName forKey:kUserAttributeLastName];
    [encoder encodeObject:self.email forKey:kUserAttributeEmail];
    [encoder encodeObject:self.avatar forKey:kUserAttributeAvatar];
    [encoder encodeObject:self.custom forKey:kUserAttributeCustom];
    [encoder encodeObject:self.updatedAt forKey:kUserAttributeUpdatedAt];
    [encoder encodeObject:self.flagConfig forKey:kUserAttributeConfig];
    [encoder encodeBool:self.anonymous forKey:kUserAttributeAnonymous];
    [encoder encodeObject:self.device forKey:kUserAttributeDevice];
    [encoder encodeObject:self.os forKey:kUserAttributeOs];
    [encoder encodeObject:self.privateAttributes forKey:kUserAttributePrivateAttributes];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:kUserAttributeKey];
        self.ip = [decoder decodeObjectForKey:kUserAttributeIp];
        self.country = [decoder decodeObjectForKey:kUserAttributeCountry];
        self.name = [decoder decodeObjectForKey:kUserAttributeName];
        self.firstName = [decoder decodeObjectForKey:kUserAttributeFirstName];
        self.lastName = [decoder decodeObjectForKey:kUserAttributeLastName];
        self.email = [decoder decodeObjectForKey:kUserAttributeEmail];
        self.avatar = [decoder decodeObjectForKey:kUserAttributeAvatar];
        self.custom = [decoder decodeObjectForKey:kUserAttributeCustom];
        self.updatedAt = [decoder decodeObjectForKey:kUserAttributeUpdatedAt];
        self.flagConfig = [decoder decodeObjectForKey:kUserAttributeConfig];
        self.anonymous = [decoder decodeBoolForKey:kUserAttributeAnonymous];
        self.device = [decoder decodeObjectForKey:kUserAttributeDevice];
        self.os = [decoder decodeObjectForKey:kUserAttributeOs];
        self.privateAttributes = [decoder decodeObjectForKey:kUserAttributePrivateAttributes];
        self.flagConfigTracker = [LDFlagConfigTracker tracker];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [self init])) {
        //Process json that comes down from server
        
        self.key = [dictionary objectForKey: kUserAttributeKey];
        self.ip = [dictionary objectForKey: kUserAttributeIp];
        self.country = [dictionary objectForKey: kUserAttributeCountry];
        self.email = [dictionary objectForKey: kUserAttributeEmail];
        self.name = [dictionary objectForKey: kUserAttributeName];
        self.firstName = [dictionary objectForKey: kUserAttributeFirstName];
        self.lastName = [dictionary objectForKey: kUserAttributeLastName];
        self.avatar = [dictionary objectForKey: kUserAttributeAvatar];
        self.custom = [dictionary objectForKey: kUserAttributeCustom];
        if (self.custom) {
            self.device = [self.custom objectForKey: kUserAttributeDevice];
            self.os = [self.custom objectForKey: kUserAttributeOs];
        }
        self.anonymous = [[dictionary objectForKey: kUserAttributeAnonymous] boolValue];
        self.updatedAt = [[NSDateFormatter userDateFormatter] dateFromString:[dictionary objectForKey:kUserAttributeUpdatedAt]];
        self.flagConfig = [[LDFlagConfigModel alloc] initWithDictionary:[dictionary objectForKey:kUserAttributeConfig]];
        self.privateAttributes = [dictionary objectForKey:kUserAttributePrivateAttributes];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if(self == nil) { return nil; }

    // Need to set device
    NSString *device = [LDUtil getDeviceAsString];
    DEBUG_LOG(@"User building User with device: %@", device);
    [self setDevice:device];

    // Need to set os
    NSString *systemVersion = [LDUtil getSystemVersionAsString];
    DEBUG_LOG(@"User building User with system version: %@", systemVersion);
    [self setOs:systemVersion];

    // Need to set updated Date
    NSDate *currentDate = [NSDate date];
    DEBUG_LOG(@"User building User with updatedAt: %@", currentDate);
    [self setUpdatedAt:currentDate];

    self.custom = @{};
    self.flagConfig = [[LDFlagConfigModel alloc] init];
    self.flagConfigTracker = [LDFlagConfigTracker tracker];

    return self;
}

-(void)resetTracker {
    self.flagConfigTracker = [LDFlagConfigTracker tracker];
}

-(NSString*) description {
    return [[self dictionaryValueWithPrivateAttributesAndFlagConfig:YES] description];
}

+(NSArray<NSString *> * __nonnull) allUserAttributes {
    return @[kUserAttributeIp, kUserAttributeCountry, kUserAttributeName, kUserAttributeFirstName, kUserAttributeLastName, kUserAttributeEmail, kUserAttributeAvatar, kUserAttributeCustom];
}

-(LDUserModel*)copy {
    LDUserModel *copiedUser = [[LDUserModel alloc] initWithDictionary:[self dictionaryValueWithPrivateAttributesAndFlagConfig:NO]]; //omit the flag config because it excludes null items
    if (self.privateAttributes != nil) {
        copiedUser.privateAttributes = [NSArray arrayWithArray:self.privateAttributes]; //Private attributes are not placed into the dictionaryValue
    }
    copiedUser.flagConfig = [self.flagConfig copy];
    return copiedUser;
}

@end

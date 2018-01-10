//
//  LDUserModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDUserModel.h"
#import "LDFlagConfigModel.h"
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


@implementation LDUserModel

-(NSDictionary *)dictionaryValueWithPrivateAttributesAndFlagConfig:(BOOL)includeFlags {
    return [self dictionaryValueWithFlagConfig:includeFlags includePrivateAttributes:YES config:nil];
}

-(NSDictionary *)dictionaryValueWithFlagConfig:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate config:(LDConfig*)config {
    NSMutableArray<NSString *> *combinedPrivateAttributes = [NSMutableArray arrayWithArray:self.privateAttributes];
    [combinedPrivateAttributes addObjectsFromArray:config.privateUserAttributes];

    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    NSMutableSet *redactedPrivateAttributes = [NSMutableSet set];

    if (self.key) { [dictionary setObject:self.key forKey: kUserAttributeKey]; }
    if (self.ip && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeIp])) { [dictionary setObject:self.ip forKey: kUserAttributeIp]; }
    if (self.country && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeCountry])) { [dictionary setObject:self.country forKey: kUserAttributeCountry]; }
    if (self.name && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeName])) { [dictionary setObject:self.name forKey: kUserAttributeName]; }
    if (self.firstName && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeFirstName])) { [dictionary setObject:self.firstName forKey: kUserAttributeFirstName]; }
    if (self.lastName && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeLastName])) { [dictionary setObject:self.lastName forKey: kUserAttributeLastName]; }
    if (self.email && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeEmail])) { [dictionary setObject:self.email forKey: kUserAttributeEmail]; }
    if (self.avatar && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeAvatar])) { [dictionary setObject:self.avatar forKey: kUserAttributeAvatar]; }
    if (self.anonymous) { [dictionary setObject:@(self.anonymous) forKey: kUserAttributeAnonymous]; }
    if (self.updatedAt) { [dictionary setObject:[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] forKey:kUserAttributeUpdatedAt]; }

    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:self.custom];
    if (!includePrivate) {
        if (customDict.count > 0 && [combinedPrivateAttributes containsObject:kUserAttributeCustom]) {
            [customDict removeAllObjects];
            [redactedPrivateAttributes addObject:kUserAttributeCustom];
        } else {
            for (NSString *customKey in [self.custom allKeys]) {
                if (self.custom[customKey] && [combinedPrivateAttributes containsObject:customKey]) {
                    [customDict removeObjectForKey:customKey];
                    [redactedPrivateAttributes addObject:customKey];
                }
            }
        }
    }

    self.device ? [customDict setObject:self.device forKey:kUserAttributeDevice] : nil;
    self.os ? [customDict setObject:self.os forKey:kUserAttributeOs] : nil;
    if (customDict.count > 0) {
        [dictionary setObject:customDict forKey: kUserAttributeCustom];
    }

    if (!includePrivate) {
        if (self.ip && [combinedPrivateAttributes containsObject:kUserAttributeIp]) { [redactedPrivateAttributes addObject:kUserAttributeIp]; }
        if (self.country && [combinedPrivateAttributes containsObject:kUserAttributeCountry]) { [redactedPrivateAttributes addObject:kUserAttributeCountry]; }
        if (self.name && [combinedPrivateAttributes containsObject:kUserAttributeName]) { [redactedPrivateAttributes addObject:kUserAttributeName]; }
        if (self.firstName && [combinedPrivateAttributes containsObject:kUserAttributeFirstName]) { [redactedPrivateAttributes addObject:kUserAttributeFirstName]; }
        if (self.lastName && [combinedPrivateAttributes containsObject:kUserAttributeLastName]) { [redactedPrivateAttributes addObject:kUserAttributeLastName]; }
        if (self.email && [combinedPrivateAttributes containsObject:kUserAttributeEmail]) { [redactedPrivateAttributes addObject:kUserAttributeEmail]; }
        if (self.avatar && [combinedPrivateAttributes containsObject:kUserAttributeAvatar]) { [redactedPrivateAttributes addObject:kUserAttributeAvatar]; }

        if (redactedPrivateAttributes.count > 0) { [dictionary setObject:[redactedPrivateAttributes allObjects]  forKey:kUserAttributePrivateAttributes]; }
    }

    if (includeFlags && self.config.featuresJsonDictionary) {
        [dictionary setObject:[[self.config dictionaryValue] objectForKey:kFeaturesJsonDictionaryKey] forKey:kUserAttributeConfig];
    }

    return dictionary;
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
    [encoder encodeObject:self.config forKey:kUserAttributeConfig];
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
        self.config = [decoder decodeObjectForKey:kUserAttributeConfig];
        self.anonymous = [decoder decodeBoolForKey:kUserAttributeAnonymous];
        self.device = [decoder decodeObjectForKey:kUserAttributeDevice];
        self.os = [decoder decodeObjectForKey:kUserAttributeOs];
        self.privateAttributes = [decoder decodeObjectForKey:kUserAttributePrivateAttributes];
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
        self.config = [[LDFlagConfigModel alloc] initWithDictionary:[dictionary objectForKey:kUserAttributeConfig]];
        self.privateAttributes = [dictionary objectForKey:kUserAttributePrivateAttributes];
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    
    if(self != nil) {
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
    }
    
    return self;
}

-(NSObject *) flagValue: ( NSString * __nonnull )keyName {
    return [self.config configFlagValue: keyName];
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    BOOL value = [self.config doesConfigFlagExist: keyName];
    return value;
}

-(NSString*) description {
    return [[self dictionaryValueWithPrivateAttributesAndFlagConfig:YES] description];
}

+(NSArray<NSString *> * __nonnull) allUserAttributes {
    return @[kUserAttributeIp, kUserAttributeCountry, kUserAttributeName, kUserAttributeFirstName, kUserAttributeLastName, kUserAttributeEmail, kUserAttributeAvatar, kUserAttributeCustom];
}

@end

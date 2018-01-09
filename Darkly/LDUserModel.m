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

-(NSDictionary *)dictionaryValue {
    return [self dictionaryValueWithConfig:YES];
}

-(NSDictionary *)dictionaryValueWithConfig:(BOOL)includeConfig {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    self.key ? [dictionary setObject:self.key forKey: kUserAttributeKey] : nil;
    self.ip ? [dictionary setObject:self.ip forKey: kUserAttributeIp] : nil;
    self.country ? [dictionary setObject:self.country forKey: kUserAttributeCountry] : nil;
    self.name ? [dictionary setObject:self.name forKey: kUserAttributeName] : nil;
    self.firstName ? [dictionary setObject:self.firstName forKey: kUserAttributeFirstName] : nil;
    self.lastName ? [dictionary setObject:self.lastName forKey: kUserAttributeLastName] : nil;
    self.email ? [dictionary setObject:self.email forKey: kUserAttributeEmail] : nil;
    self.avatar ? [dictionary setObject:self.avatar forKey: kUserAttributeAvatar] : nil;
    self.custom ? [dictionary setObject:self.custom forKey: kUserAttributeCustom] : nil;
    self.anonymous ? [dictionary setObject:[NSNumber numberWithBool: self.anonymous ] forKey: kUserAttributeAnonymous] : nil;
    self.updatedAt ? [dictionary setObject:[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] forKey:kUserAttributeUpdatedAt] : nil;

    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:[dictionary objectForKey:kUserAttributeCustom]];
    self.device ? [customDict setObject:self.device forKey:kUserAttributeDevice] : nil;
    self.os ? [customDict setObject:self.os forKey:kUserAttributeOs] : nil;

    [dictionary setObject:customDict forKey:kUserAttributeCustom];

    if (includeConfig && self.config.featuresJsonDictionary) {
        [dictionary setObject:[[self.config dictionaryValue] objectForKey:kFeaturesJsonDictionaryKey] forKey:kUserAttributeConfig];
    }

    return dictionary;
}

-(NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate privateAttributesFromConfig:(NSArray<NSString *> *)configPrivateAttributes {
    NSMutableArray<NSString *> *combinedPrivateAttributes = [NSMutableArray arrayWithArray:self.privateAttributes];
    [combinedPrivateAttributes addObjectsFromArray:configPrivateAttributes];

    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    self.key ? [dictionary setObject:self.key forKey: kUserAttributeKey] : nil;
    self.ip && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeIp]) ? [dictionary setObject:self.ip forKey: kUserAttributeIp] : nil;
    self.country && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeCountry]) ? [dictionary setObject:self.country forKey: kUserAttributeCountry] : nil;
    self.name && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeName]) ? [dictionary setObject:self.name forKey: kUserAttributeName] : nil;
    self.firstName && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeFirstName]) ? [dictionary setObject:self.firstName forKey: kUserAttributeFirstName] : nil;
    self.lastName && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeLastName]) ? [dictionary setObject:self.lastName forKey: kUserAttributeLastName] : nil;
    self.email && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeEmail]) ? [dictionary setObject:self.email forKey: kUserAttributeEmail] : nil;
    self.avatar && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeAvatar]) ? [dictionary setObject:self.avatar forKey: kUserAttributeAvatar] : nil;
    self.anonymous ? [dictionary setObject:[NSNumber numberWithBool: self.anonymous ] forKey: kUserAttributeAnonymous] : nil;
    self.updatedAt ? [dictionary setObject:[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] forKey:kUserAttributeUpdatedAt] : nil;

    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:self.custom];
    self.device && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeDevice]) ? [customDict setObject:self.device forKey:kUserAttributeDevice] : nil;
    self.os && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeOs]) ? [customDict setObject:self.os forKey:kUserAttributeOs] : nil;
    if (!includePrivate) { [customDict removeObjectsForKeys:combinedPrivateAttributes]; }
    customDict.count > 0  && (includePrivate || ![combinedPrivateAttributes containsObject:kUserAttributeCustom]) ? [dictionary setObject:customDict forKey: kUserAttributeCustom] : nil;

    combinedPrivateAttributes.count > 0 && !includePrivate ? [dictionary setObject:combinedPrivateAttributes forKey:kUserAttributePrivateAttributes] : nil;

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

- (nonnull NSString *) convertToJson {
    NSError *writeError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self dictionaryValueWithConfig:NO] options:0 error:&writeError];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return result;
}

-(NSObject *) flagValue: ( NSString * __nonnull )keyName {
    return [self.config configFlagValue: keyName];
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    BOOL value = [self.config doesConfigFlagExist: keyName];
    return value;
}

-(NSString*) description {
    return [[self dictionaryValueWithFlags:YES includePrivateAttributes:YES privateAttributesFromConfig:nil] description];
}

+(NSArray<NSString *> * __nonnull) allUserAttributes {
    return @[kUserAttributeIp, kUserAttributeCountry, kUserAttributeName, kUserAttributeFirstName, kUserAttributeLastName, kUserAttributeEmail, kUserAttributeAvatar, kUserAttributeCustom, kUserAttributeDevice, kUserAttributeOs];
}

@end

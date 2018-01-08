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

NSString * const kUserPropertyNameKey = @"key";
NSString * const kUserPropertyNameIp = @"ip";
NSString * const kUserPropertyNameCountry = @"country";
NSString * const kUserPropertyNameName = @"name";
NSString * const kUserPropertyNameFirstName = @"firstName";
NSString * const kUserPropertyNameLastName = @"lastName";
NSString * const kUserPropertyNameEmail = @"email";
NSString * const kUserPropertyNameAvatar = @"avatar";
NSString * const kUserPropertyNameCustom = @"custom";
NSString * const kUserPropertyNameUpdatedAt = @"updatedAt";
NSString * const kUserPropertyNameConfig = @"config";
NSString * const kUserPropertyNameAnonymous = @"anonymous";
NSString * const kUserPropertyNameDevice = @"device";
NSString * const kUserPropertyNameOs = @"os";
NSString * const kUserPropertyNamePrivateAttributes = @"privateAttrs";


@implementation LDUserModel

-(NSDictionary *)dictionaryValue {
    return [self dictionaryValueWithConfig:YES];
}

-(NSDictionary *)dictionaryValueWithConfig:(BOOL)includeConfig {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    self.key ? [dictionary setObject:self.key forKey: kUserPropertyNameKey] : nil;
    self.ip ? [dictionary setObject:self.ip forKey: kUserPropertyNameIp] : nil;
    self.country ? [dictionary setObject:self.country forKey: kUserPropertyNameCountry] : nil;
    self.name ? [dictionary setObject:self.name forKey: kUserPropertyNameName] : nil;
    self.firstName ? [dictionary setObject:self.firstName forKey: kUserPropertyNameFirstName] : nil;
    self.lastName ? [dictionary setObject:self.lastName forKey: kUserPropertyNameLastName] : nil;
    self.email ? [dictionary setObject:self.email forKey: kUserPropertyNameEmail] : nil;
    self.avatar ? [dictionary setObject:self.avatar forKey: kUserPropertyNameAvatar] : nil;
    self.custom ? [dictionary setObject:self.custom forKey: kUserPropertyNameCustom] : nil;
    self.anonymous ? [dictionary setObject:[NSNumber numberWithBool: self.anonymous ] forKey: kUserPropertyNameAnonymous] : nil;
    self.updatedAt ? [dictionary setObject:[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] forKey:kUserPropertyNameUpdatedAt] : nil;

    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:[dictionary objectForKey:kUserPropertyNameCustom]];
    self.device ? [customDict setObject:self.device forKey:kUserPropertyNameDevice] : nil;
    self.os ? [customDict setObject:self.os forKey:kUserPropertyNameOs] : nil;

    [dictionary setObject:customDict forKey:kUserPropertyNameCustom];

    if (includeConfig && self.config.featuresJsonDictionary) {
        [dictionary setObject:[[self.config dictionaryValue] objectForKey:kFeaturesJsonDictionaryKey] forKey:kUserPropertyNameConfig];
    }

    return dictionary;
}

-(NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateProperties:(BOOL)includePrivate privateProperties:(NSArray<NSString *> *)privateProperties {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];

    self.key ? [dictionary setObject:self.key forKey: kUserPropertyNameKey] : nil;
    self.ip && (includePrivate || ![privateProperties containsObject:kUserPropertyNameIp]) ? [dictionary setObject:self.ip forKey: kUserPropertyNameIp] : nil;
    self.country && (includePrivate || ![privateProperties containsObject:kUserPropertyNameCountry]) ? [dictionary setObject:self.country forKey: kUserPropertyNameCountry] : nil;
    self.name && (includePrivate || ![privateProperties containsObject:kUserPropertyNameName]) ? [dictionary setObject:self.name forKey: kUserPropertyNameName] : nil;
    self.firstName && (includePrivate || ![privateProperties containsObject:kUserPropertyNameFirstName]) ? [dictionary setObject:self.firstName forKey: kUserPropertyNameFirstName] : nil;
    self.lastName && (includePrivate || ![privateProperties containsObject:kUserPropertyNameLastName]) ? [dictionary setObject:self.lastName forKey: kUserPropertyNameLastName] : nil;
    self.email && (includePrivate || ![privateProperties containsObject:kUserPropertyNameEmail]) ? [dictionary setObject:self.email forKey: kUserPropertyNameEmail] : nil;
    self.avatar && (includePrivate || ![privateProperties containsObject:kUserPropertyNameAvatar]) ? [dictionary setObject:self.avatar forKey: kUserPropertyNameAvatar] : nil;
    self.anonymous ? [dictionary setObject:[NSNumber numberWithBool: self.anonymous ] forKey: kUserPropertyNameAnonymous] : nil;
    self.updatedAt ? [dictionary setObject:[[NSDateFormatter userDateFormatter] stringFromDate:self.updatedAt] forKey:kUserPropertyNameUpdatedAt] : nil;

    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:self.custom];
    self.device && (includePrivate || ![privateProperties containsObject:kUserPropertyNameDevice]) ? [customDict setObject:self.device forKey:kUserPropertyNameDevice] : nil;
    self.os && (includePrivate || ![privateProperties containsObject:kUserPropertyNameOs]) ? [customDict setObject:self.os forKey:kUserPropertyNameOs] : nil;
    if (!includePrivate) { [customDict removeObjectsForKeys:privateProperties]; }
    customDict.count > 0  && (includePrivate || ![privateProperties containsObject:kUserPropertyNameCustom]) ? [dictionary setObject:customDict forKey: kUserPropertyNameCustom] : nil;

    privateProperties.count > 0 && !includePrivate ? [dictionary setObject:privateProperties forKey:kUserPropertyNamePrivateAttributes] : nil;

    if (includeFlags && self.config.featuresJsonDictionary) {
        [dictionary setObject:[[self.config dictionaryValue] objectForKey:kFeaturesJsonDictionaryKey] forKey:kUserPropertyNameConfig];
    }

    return dictionary;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:kUserPropertyNameKey];
    [encoder encodeObject:self.ip forKey:kUserPropertyNameIp];
    [encoder encodeObject:self.country forKey:kUserPropertyNameCountry];
    [encoder encodeObject:self.name forKey:kUserPropertyNameName];
    [encoder encodeObject:self.firstName forKey:kUserPropertyNameFirstName];
    [encoder encodeObject:self.lastName forKey:kUserPropertyNameLastName];
    [encoder encodeObject:self.email forKey:kUserPropertyNameEmail];
    [encoder encodeObject:self.avatar forKey:kUserPropertyNameAvatar];
    [encoder encodeObject:self.custom forKey:kUserPropertyNameCustom];
    [encoder encodeObject:self.updatedAt forKey:kUserPropertyNameUpdatedAt];
    [encoder encodeObject:self.config forKey:kUserPropertyNameConfig];
    [encoder encodeBool:self.anonymous forKey:kUserPropertyNameAnonymous];
    [encoder encodeObject:self.device forKey:kUserPropertyNameDevice];
    [encoder encodeObject:self.os forKey:kUserPropertyNameOs];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:kUserPropertyNameKey];
        self.ip = [decoder decodeObjectForKey:kUserPropertyNameIp];
        self.country = [decoder decodeObjectForKey:kUserPropertyNameCountry];
        self.name = [decoder decodeObjectForKey:kUserPropertyNameName];
        self.firstName = [decoder decodeObjectForKey:kUserPropertyNameFirstName];
        self.lastName = [decoder decodeObjectForKey:kUserPropertyNameLastName];
        self.email = [decoder decodeObjectForKey:kUserPropertyNameEmail];
        self.avatar = [decoder decodeObjectForKey:kUserPropertyNameAvatar];
        self.custom = [decoder decodeObjectForKey:kUserPropertyNameCustom];
        self.updatedAt = [decoder decodeObjectForKey:kUserPropertyNameUpdatedAt];
        self.config = [decoder decodeObjectForKey:kUserPropertyNameConfig];
        self.anonymous = [decoder decodeBoolForKey:kUserPropertyNameAnonymous];
        self.device = [decoder decodeObjectForKey:kUserPropertyNameDevice];
        self.os = [decoder decodeObjectForKey:kUserPropertyNameOs];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [self init])) {
        //Process json that comes down from server
        
        self.key = [dictionary objectForKey: kUserPropertyNameKey];
        self.ip = [dictionary objectForKey: kUserPropertyNameIp];
        self.country = [dictionary objectForKey: kUserPropertyNameCountry];
        self.email = [dictionary objectForKey: kUserPropertyNameEmail];
        self.name = [dictionary objectForKey: kUserPropertyNameName];
        self.firstName = [dictionary objectForKey: kUserPropertyNameFirstName];
        self.lastName = [dictionary objectForKey: kUserPropertyNameLastName];
        self.avatar = [dictionary objectForKey: kUserPropertyNameAvatar];
        self.custom = [dictionary objectForKey: kUserPropertyNameCustom];
        if (self.custom) {
            self.device = [self.custom objectForKey: kUserPropertyNameDevice];
            self.os = [self.custom objectForKey: kUserPropertyNameOs];
        }
        self.anonymous = [[dictionary objectForKey: kUserPropertyNameAnonymous] boolValue];
        self.updatedAt = [[NSDateFormatter userDateFormatter] dateFromString:[dictionary objectForKey:kUserPropertyNameUpdatedAt]];
        self.config = [[LDFlagConfigModel alloc] initWithDictionary:[dictionary objectForKey:kUserPropertyNameConfig]];
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
    return [self.dictionaryValue description];
}

+(NSArray<NSString *> * __nonnull) allUserPropertyNames {
    return @[kUserPropertyNameIp, kUserPropertyNameCountry, kUserPropertyNameName, kUserPropertyNameFirstName, kUserPropertyNameLastName, kUserPropertyNameEmail, kUserPropertyNameAvatar, kUserPropertyNameCustom, kUserPropertyNameDevice, kUserPropertyNameOs];
}

@end

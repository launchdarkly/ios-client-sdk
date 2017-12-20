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

static NSString * const kUserPropertyNameKey = @"key";
static NSString * const kUserPropertyNameIp = @"ip";
static NSString * const kUserPropertyNameCountry = @"country";
static NSString * const kUserPropertyNameName = @"name";
static NSString * const kUserPropertyNameFirstName = @"firstName";
static NSString * const kUserPropertyNameLastName = @"lastName";
static NSString * const kUserPropertyNameEmail = @"email";
static NSString * const kUserPropertyNameAvatar = @"avatar";
static NSString * const kUserPropertyNameCustom = @"custom";
static NSString * const kUserPropertyNameUpdatedAt = @"updatedAt";
static NSString * const kUserPropertyNameConfig = @"config";
static NSString * const kUserPropertyNameAnonymous = @"anonymous";
static NSString * const kUserPropertyNameDevice = @"device";
static NSString * const kUserPropertyNameOs = @"os";


@implementation LDUserModel

-(NSDictionary *)dictionaryValue {
    return [self dictionaryValueWithConfig:YES];
}

-(NSDictionary *)dictionaryValueWithConfig:(BOOL)includeConfig {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    
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
    self.updatedAt ? [dictionary setObject:[formatter stringFromDate:self.updatedAt] forKey:kUserPropertyNameUpdatedAt] : nil;
    
    NSMutableDictionary *customDict = [[NSMutableDictionary alloc] initWithDictionary:[dictionary objectForKey:kUserPropertyNameCustom]];
    self.device ? [customDict setObject:self.device forKey:kUserPropertyNameDevice] : nil;
    self.os ? [customDict setObject:self.os forKey:kUserPropertyNameOs] : nil;
    
    [dictionary setObject:customDict forKey:kUserPropertyNameCustom];
    
    if (includeConfig && self.config.featuresJsonDictionary) {
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
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        
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
        self.updatedAt = [formatter dateFromString:[dictionary objectForKey:kUserPropertyNameUpdatedAt]];
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

@end

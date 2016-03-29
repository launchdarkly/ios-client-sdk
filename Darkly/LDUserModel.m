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

static NSString * const kKeyKey = @"key";
static NSString * const kIpKey = @"ip";
static NSString * const kCountryKey = @"country";
static NSString * const kFirstNameKey = @"firstName";
static NSString * const kLastNameKey = @"lastName";
static NSString * const kEmailKey = @"email";
static NSString * const kAvatarKey = @"avatar";
static NSString * const kCustomKey = @"custom";
static NSString * const kUpdatedAtKey = @"updatedAt";
static NSString * const kConfigKey = @"config";
static NSString * const kAnonymousKey = @"anonymous";
static NSString * const kDeviceKey = @"device";
static NSString * const kOsKey = @"os";


@implementation LDUserModel

-(NSDictionary *)dictionaryValue{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    
    self.key ? [dictionary setObject:self.key forKey: kKeyKey] : nil;
    self.ip ? [dictionary setObject:self.ip forKey: kIpKey] : nil;
    self.country ? [dictionary setObject:self.country forKey: kCountryKey] : nil;
    self.firstName ? [dictionary setObject:self.firstName forKey: kFirstNameKey] : nil;
    self.lastName ? [dictionary setObject:self.lastName forKey: kLastNameKey] : nil;
    self.email ? [dictionary setObject:self.email forKey: kEmailKey] : nil;
    self.avatar ? [dictionary setObject:self.avatar forKey: kAvatarKey] : nil;
    self.custom ? [dictionary setObject:self.custom forKey: kCustomKey] : nil;
    self.updatedAt ? [dictionary setObject:[formatter stringFromDate: self.updatedAt] forKey: kUpdatedAtKey] : nil;
    self.anonymous ? [dictionary setObject:[NSNumber numberWithBool: self.anonymous ] forKey: kAnonymousKey] : nil;
    self.device ? [dictionary setObject:self.device forKey: kDeviceKey] : nil;
    self.os ? [dictionary setObject:self.os forKey: kOsKey] : nil;
    self.config ? [dictionary setObject:[self.config dictionaryValue] forKey: kConfigKey] : nil;
    
    return dictionary;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:kKeyKey];
    [encoder encodeObject:self.ip forKey:kIpKey];
    [encoder encodeObject:self.country forKey:kCountryKey];
    [encoder encodeObject:self.firstName forKey:kFirstNameKey];
    [encoder encodeObject:self.lastName forKey:kLastNameKey];
    [encoder encodeObject:self.email forKey:kEmailKey];
    [encoder encodeObject:self.avatar forKey:kAvatarKey];
    [encoder encodeObject:self.custom forKey:kCustomKey];
    [encoder encodeObject:self.updatedAt forKey:kUpdatedAtKey];
    [encoder encodeObject:self.config forKey:kConfigKey];
    [encoder encodeBool:self.anonymous forKey:kAnonymousKey];
    [encoder encodeObject:self.device forKey:kDeviceKey];
    [encoder encodeObject:self.os forKey:kOsKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:kKeyKey];
        self.ip = [decoder decodeObjectForKey:kIpKey];
        self.country = [decoder decodeObjectForKey:kCountryKey];
        self.firstName = [decoder decodeObjectForKey:kFirstNameKey];
        self.lastName = [decoder decodeObjectForKey:kLastNameKey];
        self.email = [decoder decodeObjectForKey:kEmailKey];
        self.avatar = [decoder decodeObjectForKey:kAvatarKey];
        self.custom = [decoder decodeObjectForKey:kCustomKey];
        self.updatedAt = [decoder decodeObjectForKey:kUpdatedAtKey];
        self.config = [decoder decodeObjectForKey:kConfigKey];
        self.anonymous = [decoder decodeBoolForKey:kAnonymousKey];
        self.device = [decoder decodeObjectForKey:kDeviceKey];
        self.os = [decoder decodeObjectForKey:kOsKey];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [self init])) {
        //Process json that comes down from server
        self.key = [dictionary objectForKey: kKeyKey];
        self.ip = [dictionary objectForKey: kIpKey];
        self.country = [dictionary objectForKey: kCountryKey];
        self.email = [dictionary objectForKey: kEmailKey];
        self.firstName = [dictionary objectForKey: kFirstNameKey];
        self.lastName = [dictionary objectForKey: kLastNameKey];
        self.avatar = [dictionary objectForKey: kAvatarKey];
        self.custom = [dictionary objectForKey: kCustomKey];
        self.device = [dictionary objectForKey: kDeviceKey];
        self.os = [dictionary objectForKey: kOsKey];
        self.anonymous = [dictionary objectForKey: kAnonymousKey];
        self.config = [[LDFlagConfigModel alloc] initWithDictionary:[dictionary objectForKey:kConfigKey]];
        if ([dictionary objectForKey:kUpdatedAtKey]) {
            self.updatedAt = [dictionary objectForKey:kUpdatedAtKey];
        }
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
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self dictionaryValue] options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *result = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return result;
}

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName {
    return [self.config isFlagOn: keyName];
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    return [self.config doesFlagExist: keyName];
}

@end

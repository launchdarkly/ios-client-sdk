//
//  LDUserModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDUserModel.h"
#import "LDFlagConfigModel.h"

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

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName {
    return [self.config isFlagOn: keyName];
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    return [self.config doesFlagExist: keyName];
}

@end

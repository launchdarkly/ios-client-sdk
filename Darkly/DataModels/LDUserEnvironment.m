//
//  LDUserEnvironment.m
//  Darkly
//
//  Created by Mark Pokorny on 10/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDUserEnvironment.h"
#import "LDUserModel.h"
#import "NSDictionary+LaunchDarkly.h"

NSString *const kUserEnvironmentKeyUserKey = @"userKey";
NSString *const kUserEnvironmentKeyEnvironments = @"environments";

@interface LDUserEnvironment ()
@property (nonatomic, strong) NSString *userKey;
@property (nonatomic, strong) NSDictionary<NSString*, LDUserModel*> *users;     // <mobileKey, LDUserModel>
@end

@implementation LDUserEnvironment

//Each LDUserModel passed in through environments must match the userKey in order to be included. Any that do not match will be excluded.
+(instancetype)userEnvironmentForUserWithKey:(NSString*)userKey environments:(NSDictionary<NSString*, LDUserModel*>*)environments {
    return [[LDUserEnvironment alloc] initForUserWithKey:userKey environments:environments];
}

-(instancetype)initForUserWithKey:(NSString*)userKey environments:(NSDictionary<NSString*, LDUserModel*>*)environments {
    if (!(self = [super init])) { return nil; }
    if (userKey.length == 0) {
        return nil;
    }
    //Filter out users with keys that don't match userKey
    NSDictionary<NSString*, LDUserModel*> *matchingEnvironments = [environments compactMapUsingBlock:^id(id _Nonnull originalValue) {
        if (![originalValue isKindOfClass:[LDUserModel class]]) {
            return nil;
        }
        LDUserModel *user = originalValue;
        if (![user.key isEqualToString:userKey]) {
            return nil;
        }
        return user;
    }];

    self.userKey = userKey;
    self.users = matchingEnvironments ?: [NSDictionary dictionary];

    return self;
}

-(instancetype)initWithCoder:(NSCoder*)coder {
    self = [self init];

    self.userKey = [coder decodeObjectForKey:kUserEnvironmentKeyUserKey];
    if (self.userKey.length == 0) {
        return nil;
    }
    self.users = [coder decodeObjectForKey:kUserEnvironmentKeyEnvironments] ?: [NSDictionary dictionary];

    return self;
}

-(void)encodeWithCoder:(NSCoder*)coder {
    [coder encodeObject:self.userKey forKey:kUserEnvironmentKeyUserKey];
    [coder encodeObject:self.users forKey:kUserEnvironmentKeyEnvironments];
}

-(instancetype)initWithDictionary:(NSDictionary*)dictionary {
    NSString *userKey = dictionary[kUserEnvironmentKeyUserKey];
    if (userKey.length == 0) {
        return nil;
    }
    self = [self init];
    self.userKey = userKey;
    self.users = [dictionary[kUserEnvironmentKeyEnvironments] compactMapUsingBlock:^id(id _Nonnull originalValue) {
        if (![originalValue isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        NSDictionary *userDictionary = originalValue;
        return [[LDUserModel alloc] initWithDictionary:userDictionary];
    }];

    return self;
}

-(NSDictionary*)dictionaryValue {
    if (self.userKey.length == 0) {
        return nil;
    }
    NSDictionary *usersDictionary = [self.users compactMapUsingBlock:^id(id _Nonnull originalValue) {
        if (![originalValue isKindOfClass:[LDUserModel class]]) {
            return nil;
        }
        LDUserModel *originalUser = originalValue;
        return [originalUser dictionaryValueWithPrivateAttributesAndFlagConfig:YES];
    }];
    return @{kUserEnvironmentKeyUserKey:self.userKey, kUserEnvironmentKeyEnvironments:usersDictionary ?: [NSDictionary dictionary]};
}

-(NSDate*)lastUpdated {
    if (self.users.count == 0) {
        return nil;
    }
    NSArray<NSDate*> *usersUpdatedAt = [self.users compactMapUsingBlock:^id(id _Nonnull originalValue) {
        if (![originalValue isKindOfClass:[LDUserModel class]]) {
            return nil;
        }
        LDUserModel *originalUser = originalValue;
        return originalUser.updatedAt;
    }].allValues;
    if (usersUpdatedAt.count == 0) {
        return nil;
    }
    NSArray *sortedUsersUpdatedAt = [usersUpdatedAt sortedArrayUsingComparator:^NSComparisonResult(NSDate * _Nonnull date1, NSDate * _Nonnull date2) {
        return [date1 compare:date2];
    }];
    return sortedUsersUpdatedAt.lastObject;
}

-(LDUserModel*)userForMobileKey:(NSString*)mobileKey {
    return self.users[mobileKey];
}

-(void)setUser:(LDUserModel*)user mobileKey:(NSString*)mobileKey {
    if (mobileKey.length == 0 || user == nil || ![user.key isEqualToString:self.userKey]) {
        return;
    }
    NSMutableDictionary *updatedUsers = [NSMutableDictionary dictionaryWithDictionary:self.users];
    updatedUsers[mobileKey] = user;
    self.users = [updatedUsers copy];
}

-(void)removeUserForMobileKey:(NSString*)mobileKey {
    if (mobileKey.length == 0) {
        return;
    }
    NSMutableDictionary *updatedUsers = [NSMutableDictionary dictionaryWithDictionary:self.users];
    [updatedUsers removeObjectForKey:mobileKey];
    self.users = [updatedUsers copy];
}

-(NSString*)description {
    NSString *mobileKeys = [self.users.allKeys componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"<%@ %p: userKey:%@, mobileKeys:%@>", NSStringFromClass([self class]), self, self.userKey, mobileKeys];
}

@end

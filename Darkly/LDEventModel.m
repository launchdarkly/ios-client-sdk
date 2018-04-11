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

NSString * const kKeyKey = @"key";
NSString * const kKeyKind = @"kind";
NSString * const kKeyCreationDate = @"creationDate";
NSString * const kKeyData = @"data";
NSString * const kKeyValue = @"value";
NSString * const kKeyIsDefault = @"isDefault";
NSString * const kKeyDefault = @"default";
NSString * const kKeyUser = @"user";
NSString * const kKeyUserKey = @"userKey";
NSString * const kKeyInlineUser = @"inlineUser";

NSString * const kEventNameFeature = @"feature";
NSString * const kEventNameCustom = @"custom";
NSString * const kEventNameIdentify = @"identify";

@implementation LDEventModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.key forKey:kKeyKey];
    [encoder encodeObject:self.kind forKey:kKeyKind];
    [encoder encodeInteger:self.creationDate forKey:kKeyCreationDate];
    [encoder encodeObject:self.data forKey:kKeyData];
    [encoder encodeObject:self.value forKey:kKeyValue];
    [encoder encodeObject:self.defaultValue forKey:kKeyDefault];
    [encoder encodeObject:self.user forKey:kKeyUser];
    [encoder encodeBool:self.inlineUser forKey:kKeyInlineUser];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if(!(self = [super init])) { return nil; }

    self.key = [decoder decodeObjectForKey:kKeyKey];
    self.kind = [decoder decodeObjectForKey:kKeyKind];
    self.creationDate = [decoder decodeIntegerForKey:kKeyCreationDate];
    self.data = [decoder decodeObjectForKey:kKeyData];
    self.value = [decoder decodeObjectForKey:kKeyValue];
    self.defaultValue = [decoder decodeObjectForKey:kKeyDefault];
    if (!self.defaultValue) {
        self.defaultValue = [decoder decodeObjectForKey:kKeyIsDefault];
    }
    self.user = [decoder decodeObjectForKey:kKeyUser];
    self.inlineUser = [decoder decodeBoolForKey:kKeyInlineUser];

    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if(!(self = [super init])) { return nil; }

    //Process json that comes down from server
    self.key = [dictionary objectForKey: kKeyKey];
    self.kind = [dictionary objectForKey: kKeyKind];
    NSNumber *creationDateValue = [dictionary objectForKey:kKeyCreationDate];
    self.creationDate = [creationDateValue longValue];
    self.value = [dictionary objectForKey: kKeyValue];
    self.defaultValue = [dictionary objectForKey: kKeyDefault];
    self.data = [dictionary objectForKey:kKeyData];
    self.user = [[LDUserModel alloc] initWithDictionary:[dictionary objectForKey:kKeyUser]];
    self.inlineUser = [[dictionary objectForKey:kKeyInlineUser] boolValue];

    return self;
}

+(nullable instancetype)featureEventWithKey:(nonnull NSString *)featureKey
                                   keyValue:(NSObject * _Nullable)keyValue
                            defaultKeyValue:(NSObject * _Nullable)defaultKeyValue
                                  userValue:(nonnull LDUserModel *)userValue
                                 inlineUser:(BOOL)inlineUser {
    return [[LDEventModel alloc] initFeatureEventWithKey:featureKey keyValue:keyValue defaultKeyValue:defaultKeyValue userValue:userValue inlineUser:inlineUser];
}

-(instancetype)initFeatureEventWithKey:(nonnull NSString *)featureKey
                              keyValue:(NSObject*)keyValue
                       defaultKeyValue:(NSObject*)defaultKeyValue
                             userValue:(LDUserModel *)userValue
                            inlineUser:(BOOL)inlineUser {
    if (!(self = [self init])) { return nil; }

    self.key = featureKey;
    self.kind = kEventNameFeature;
    self.value = keyValue;
    self.defaultValue = defaultKeyValue;
    self.user = userValue;
    self.inlineUser = inlineUser;

    return self;
}

+(instancetype)customEventWithKey: (NSString *)featureKey
                andDataDictionary: (NSDictionary *)customData
                        userValue:(LDUserModel *)userValue
                       inlineUser:(BOOL)inlineUser {
    return [[LDEventModel alloc] initCustomEventWithKey:featureKey andDataDictionary:customData userValue:userValue inlineUser:inlineUser];
}

-(instancetype)initCustomEventWithKey: (NSString *)featureKey
                    andDataDictionary: (NSDictionary *)customData
                            userValue:(LDUserModel *)userValue
                           inlineUser:(BOOL)inlineUser {
    if(!(self = [self init])) { return nil; }

    self.key = featureKey;
    self.kind = kEventNameCustom;
    self.data = customData;
    self.user = userValue;
    self.inlineUser = inlineUser;

    return self;
}

+(nullable instancetype)identifyEventWithUser:(nonnull LDUserModel*)user {
    return [[LDEventModel alloc] initIdentifyEventWithUser:user];
}

-(nullable instancetype)initIdentifyEventWithUser:(nonnull LDUserModel*)user {
    if(!(self = [self init])) { return nil; }

    self.key = user.key;
    self.kind = kEventNameIdentify;
    self.user = user;
    self.inlineUser = YES;

    return self;
}

- (instancetype)init {
    self = [super init];
    
    if(self != nil) {
        // Need to set creationDate
        self.creationDate = [[NSDate date] millisSince1970];
    }
    
    return self;
}


-(NSDictionary *)dictionaryValueUsingConfig:(LDConfig*)config {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    self.key ? [dictionary setObject:self.key forKey: kKeyKey] : nil;
    self.kind ? [dictionary setObject:self.kind forKey: kKeyKind] : nil;
    self.creationDate ? [dictionary setObject:[NSNumber numberWithInteger: self.creationDate] forKey: kKeyCreationDate] : nil;
    self.data ? [dictionary setObject:self.data forKey: kKeyData] : nil;
    self.value ? [dictionary setObject:self.value forKey: kKeyValue] : nil;
    self.defaultValue ? [dictionary setObject:self.defaultValue forKey: kKeyDefault] : nil;
    if (self.inlineUser || [self.kind isEqualToString:kEventNameIdentify]) {
        self.user ? [dictionary setObject:[self.user dictionaryValueWithFlagConfig:NO includePrivateAttributes:NO config:config] forKey: kKeyUser] : nil;
    } else {
        self.user ? dictionary[kKeyUserKey] = self.user.key : nil;
    }
    dictionary[kKeyInlineUser] = @(self.inlineUser);

    return dictionary;
}

@end

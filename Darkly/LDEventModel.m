//
//  LDEventModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDEventModel.h"
#import "LDUserModel.h"

static NSString * const kKeyKey = @"key";
static NSString * const kKindKey = @"kind";
static NSString * const kCreationDateKey = @"creationDate";
static NSString * const kDataKey = @"data";
static NSString * const kFeatureKeyValueKey = @"value";
static NSString * const kIsDefaultKey = @"isDefault";
static NSString * const kUserKey = @"user";

static NSString * const kFeatureKeyValueServerKey = @"value";
static NSString * const kIsDefaultServerKey = @"default";

static NSString * const kFeatureEventName = @"feature";
static NSString * const kCustomEventName = @"custom";

@implementation LDEventModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:kKeyKey];
    [encoder encodeObject:self.kind forKey:kKindKey];
    [encoder encodeInteger:self.creationDate forKey:kCreationDateKey];
    [encoder encodeObject:self.data forKey:kDataKey];
    [encoder encodeObject:self.value forKey:kFeatureKeyValueKey];
    [encoder encodeObject:self.isDefault forKey:kIsDefaultKey];
    [encoder encodeObject:self.user forKey:kUserKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:kKeyKey];
        self.kind = [decoder decodeObjectForKey:kKindKey];
        self.creationDate = [decoder decodeIntegerForKey:kCreationDateKey];
        self.data = [decoder decodeObjectForKey:kDataKey];
        self.value = [decoder decodeObjectForKey:kFeatureKeyValueKey];
        self.isDefault = [decoder decodeObjectForKey:kIsDefaultKey];
        self.user = [decoder decodeObjectForKey:kUserKey];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [super init])) {
        //Process json that comes down from server
        self.key = [dictionary objectForKey: kKeyKey];
        self.kind = [dictionary objectForKey: kKindKey];
        NSNumber *creationDateValue = [dictionary objectForKey:kCreationDateKey];
        self.creationDate = [creationDateValue longValue];
        self.value = [dictionary objectForKey: kFeatureKeyValueServerKey];
        self.isDefault = [dictionary objectForKey: kIsDefaultServerKey];
        self.user = [[LDUserModel alloc] initWithDictionary:[dictionary objectForKey:kUserKey]];
    }
    return self;
}

-(instancetype)initFeatureEventWithKey:(nonnull NSString *)featureKey keyValue:(NSObject*)keyValue defaultKeyValue:(NSObject*)defaultKeyValue userValue:(LDUserModel *)userValue {
    if((self = [self init])) {
        self.key = featureKey;
        self.kind = kFeatureEventName;
        self.value = keyValue;
        self.isDefault = defaultKeyValue;
        self.user = userValue;
    }
    
    return self;
}

-(instancetype)initCustomEventWithKey: (NSString *)featureKey
                 andDataDictionary: (NSDictionary *)customData userValue:(LDUserModel *)userValue  {
    if((self = [self init])) {
        self.key = featureKey;
        self.kind = kCustomEventName;
        self.data = customData;
        self.user = userValue;
    }
    
    return self;
}

- (instancetype)init {
    self = [super init];
    
    if(self != nil) {
        // Need to set creationDate
        self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    }
    
    return self;
}


-(NSDictionary *)dictionaryValueUsingConfig:(LDConfig*)config {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    self.key ? [dictionary setObject:self.key forKey: kKeyKey] : nil;
    self.kind ? [dictionary setObject:self.kind forKey: kKindKey] : nil;
    self.creationDate ? [dictionary setObject:[NSNumber numberWithInteger: self.creationDate] forKey: kCreationDateKey] : nil;
    self.data ? [dictionary setObject:self.data forKey: kDataKey] : nil;
    self.value ? [dictionary setObject:self.value forKey: kFeatureKeyValueServerKey] : nil;
    self.isDefault ? [dictionary setObject:self.isDefault forKey: kIsDefaultServerKey] : nil;
    self.user ? [dictionary setObject:[self.user dictionaryValueWithFlagConfig:NO includePrivateAttributes:NO config:config] forKey: kUserKey] : nil;
    
    return dictionary;
}

@end

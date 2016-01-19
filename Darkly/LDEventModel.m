//
//  LDEventModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDEventModel.h"

static NSString * const kKeyKey = @"key";
static NSString * const kKindKey = @"kind";
static NSString * const kCreationDateKey = @"creationDate";
static NSString * const kDataKey = @"data";
static NSString * const kFeatureKeyValueKey = @"featureKeyValue";
static NSString * const kIsDefaultKey = @"isDefault";

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
    [encoder encodeBool:self.featureKeyValue forKey:kFeatureKeyValueKey];
    [encoder encodeBool:self.isDefault forKey:kIsDefaultKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:kKeyKey];
        self.kind = [decoder decodeObjectForKey:kKindKey];
        self.creationDate = [decoder decodeIntegerForKey:kCreationDateKey];
        self.data = [decoder decodeObjectForKey:kDataKey];
        self.featureKeyValue = [decoder decodeBoolForKey:kFeatureKeyValueKey];
        self.isDefault = [decoder decodeBoolForKey:kIsDefaultKey];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [super init])) {
        //Process json that comes down from server
        self.key = [dictionary objectForKey: kKeyKey];
        self.kind = [dictionary objectForKey: kKindKey];
        NSNumber *creationDateValue = [dictionary objectForKey:kCreationDateKey];
        self.creationDate = [creationDateValue boolValue];
        self.featureKeyValue = [dictionary objectForKey: kFeatureKeyValueServerKey];
        self.isDefault = [dictionary objectForKey: kIsDefaultServerKey];
    }
    return self;
}

-(instancetype)featureEventWithKey:(nonnull NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    self.key = featureKey;
    self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    self.kind = kFeatureEventName;
    self.featureKeyValue = keyValue;
    self.isDefault = defaultKeyValue;
    
    return self;
}

-(instancetype) customEventWithKey: (NSString *)featureKey
                 andDataDictionary: (NSDictionary *)customData  {
    self.key = featureKey;
    self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    self.kind = kCustomEventName;
    self.data = customData;
    
    return self;
}

@end

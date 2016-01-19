//
//  LDFeatureFlagModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFeatureFlagModel.h"

static NSString * const kKeyKey = @"key";
static NSString * const kIsOnKey = @"isOn";

@implementation LDFeatureFlagModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:kKeyKey];
    [encoder encodeBool:self.isOn forKey:kIsOnKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:kKeyKey];
        self.isOn = [decoder decodeObjectForKey:kIsOnKey];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [super init])) {
        //Process json that comes down from server
        self.key = [dictionary objectForKey: kKeyKey];
        NSNumber *isOnValue = [dictionary objectForKey:kIsOnKey];
        self.isOn = [isOnValue boolValue];
    }
    return self;
}

@end

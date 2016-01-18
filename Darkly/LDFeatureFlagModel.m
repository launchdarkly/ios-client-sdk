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

@end

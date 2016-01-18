//
//  LDFeatureFlagModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFeatureFlagModel.h"

@implementation LDFeatureFlagModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:@"key"];
    [encoder encodeBool:self.isOn forKey:@"isOn"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:@"key"];
        self.isOn = [decoder decodeObjectForKey:@"isOn"];
    }
    return self;
}

@end

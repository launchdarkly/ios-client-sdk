//
//  LDEventModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDEventModel.h"

@implementation LDEventModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:@"key"];
    [encoder encodeObject:self.kind forKey:@"kind"];
    [encoder encodeInteger:self.creationDate forKey:@"creationDate"];
    [encoder encodeObject:self.data forKey:@"data"];
    [encoder encodeBool:self.featureKeyValue forKey:@"featureKeyValue"];
    [encoder encodeBool:self.isDefault forKey:@"isDefault"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:@"key"];
        self.kind = [decoder decodeObjectForKey:@"kind"];
        self.creationDate = [decoder decodeIntegerForKey:@"creationDate"];
        self.data = [decoder decodeObjectForKey:@"data"];
        self.featureKeyValue = [decoder decodeBoolForKey:@"featureKeyValue"];
        self.isDefault = [decoder decodeBoolForKey:@"isDefault"];
    }
    return self;
}

-(instancetype)featureEventWithKey:(nonnull NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    self.key = featureKey;
    self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    self.kind = @"feature";
    self.featureKeyValue = keyValue;
    self.isDefault = defaultKeyValue;
    
    return self;
}

-(instancetype) customEventWithKey: (NSString *)featureKey
                 andDataDictionary: (NSDictionary *)customData  {
    self.key = featureKey;
    self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    self.kind = @"custom";
    self.data = customData;
    
    return self;
}

@end

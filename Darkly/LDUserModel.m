//
//  LDUserModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDUserModel.h"
#import "LDFlagConfigModel.h"

@implementation LDUserModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.key forKey:@"key"];
    [encoder encodeObject:self.ip forKey:@"ip"];
    [encoder encodeObject:self.country forKey:@"country"];
    [encoder encodeObject:self.firstName forKey:@"firstName"];
    [encoder encodeObject:self.lastName forKey:@"lastName"];
    [encoder encodeObject:self.email forKey:@"email"];
    [encoder encodeObject:self.avatar forKey:@"avatar"];
    [encoder encodeObject:self.custom forKey:@"custom"];
    [encoder encodeObject:self.updatedAt forKey:@"updatedAt"];
    [encoder encodeObject:self.config forKey:@"config"];
    [encoder encodeBool:self.anonymous forKey:@"anonymous"];
    [encoder encodeObject:self.device forKey:@"device"];
    [encoder encodeObject:self.os forKey:@"os"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.key = [decoder decodeObjectForKey:@"key"];
        self.ip = [decoder decodeObjectForKey:@"ip"];
        self.country = [decoder decodeObjectForKey:@"country"];
        self.firstName = [decoder decodeObjectForKey:@"firstName"];
        self.lastName = [decoder decodeObjectForKey:@"lastName"];
        self.email = [decoder decodeObjectForKey:@"email"];
        self.avatar = [decoder decodeObjectForKey:@"avatar"];
        self.custom = [decoder decodeObjectForKey:@"custom"];
        self.updatedAt = [decoder decodeObjectForKey:@"updatedAt"];
        self.config = [decoder decodeObjectForKey:@"config"];
        self.anonymous = [decoder decodeBoolForKey:@"anonymous"];
        self.device = [decoder decodeObjectForKey:@"device"];
        self.os = [decoder decodeObjectForKey:@"os"];
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

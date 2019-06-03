//
//  NSDictionary+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSDictionary+Testable.h"
#import "LDUserModel+Testable.h"

@implementation NSDictionary(Testable)
-(BOOL)boolValueForKey:(NSString*)key {
    return [self[key] boolValue];
}

-(NSInteger)integerValueForKey:(nullable NSString*)key {
    return [self[key] integerValue];
}

-(BOOL)isEqualToUserEnvironmentUsersDictionary:(NSDictionary*)otherDictionary {
    for (NSString *environmentKey in self.allKeys) {
        LDUserModel *userForEnvironment = self[environmentKey];
        LDUserModel *otherUserForEnvironment = otherDictionary[environmentKey];
        if (![userForEnvironment isEqual:otherUserForEnvironment ignoringAttributes:@[kUserAttributeUpdatedAt]]) {
            return NO;
        }
    }
    return YES;
}

@end

//
//  LDUserBuilder+Testable.m
//  Darkly
//
//  Created by Mark Pokorny on 8/2/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDUserBuilder+Testable.h"

@implementation LDUserBuilder (Testable)
+ (instancetype)userBuilderWithKey:(NSString*)key {
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = key;
    return userBuilder;
}

@end

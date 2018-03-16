//
//  NSDictionary+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSDictionary+Testable.h"

@implementation NSDictionary(Testable)
-(BOOL)boolValueForKey:(NSString*)key {
    return [self[key] boolValue];
}

-(NSInteger)integerValueForKey:(nullable NSString*)key {
    return [self[key] integerValue];
}
@end

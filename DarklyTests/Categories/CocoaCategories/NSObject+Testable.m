//
//  NSObject+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSObject+Testable.h"

@implementation NSObject(Testable)
-(BOOL)boolValue {
    NSNumber *numberValue = (NSNumber*)self;
    if (!numberValue) { return false; }
    return [numberValue boolValue];
}

-(NSInteger)integerValue {
    NSNumber *numberValue = (NSNumber*)self;
    if (!numberValue) { return INT_MIN; }
    return [numberValue integerValue];
}
@end

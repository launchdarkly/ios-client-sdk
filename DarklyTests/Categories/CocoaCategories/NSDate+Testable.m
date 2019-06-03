//
//  NSInteger+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSDate+Testable.h"

bool Approximately(LDMillisecond num1, LDMillisecond num2, LDMillisecond range) {
    return labs(num1 - num2) <= range;
}

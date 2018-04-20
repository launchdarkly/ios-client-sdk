//
//  NSInteger+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSInteger+Testable.h"

bool Approximately(long num1, long num2, long range) {
    return labs(num1 - num2) <= range;
}

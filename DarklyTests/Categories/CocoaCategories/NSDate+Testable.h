//
//  NSDate+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDate+ReferencedDate.h"

bool Approximately(LDMillisecond num1, LDMillisecond num2, LDMillisecond range);

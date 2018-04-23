//
//  LDThrottler+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/5/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDThrottler.h"

@interface LDThrottler(Testable)
@property (nonatomic, strong) void(^timerFiredCallback)(void);
@end

//
//  LDClient+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>
#import "LDDataManager.h"
#import "LDEnvironment.h"
#import "LDEnvironmentController.h"
#import "LDThrottler.h"

@interface LDClient(Testable)
@property (nonatomic, assign) BOOL clientStarted;
@property (nonatomic, strong) LDEnvironment *primaryEnvironment;
@property (nonatomic, strong) LDThrottler *throttler;
@end

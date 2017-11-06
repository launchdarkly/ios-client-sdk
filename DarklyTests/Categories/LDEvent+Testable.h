//
//  LDEvent+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDEventSource.h"

@interface LDEvent(Testable)
+(instancetype)stubUnauthorizedEvent;
+(instancetype)stubErrorEvent;
@end

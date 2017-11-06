//
//  LDEvent+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDEvent+Testable.h"
#import "DarklyConstants.h"

@implementation LDEvent(Testable)
+(instancetype)stubUnauthorizedEvent {
    NSError *error = [NSError errorWithDomain:LDEventSourceErrorDomain code:kErrorCodeUnauthorized userInfo:nil];
    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateClosed;
    event.error = error;
    return event;
}

+(instancetype)stubErrorEvent {
    NSError *error = [NSError errorWithDomain:@"" code:2 userInfo:nil];
    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateClosed;
    event.error = error;
    return event;
}
@end

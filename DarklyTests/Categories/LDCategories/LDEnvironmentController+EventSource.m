//
//  LDEnvironmentController+EventSource.m
//  Darkly
//
//  Created by Mark Pokorny on 8/2/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDEnvironmentController+EventSource.h"
@interface LDEnvironmentController (EventSourcePrivate)
    @property(nonatomic, strong, readonly) LDEventSource *eventSource;
@end

@implementation LDEnvironmentController (EventSourcePrivate)
-(LDEventSource*)activeEventSource {
    return self.eventSource;
}
@end

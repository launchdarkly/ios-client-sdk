//
//  LDClientManager+EventSource.m
//  Darkly
//
//  Created by Mark Pokorny on 8/2/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDClientManager+EventSource.h"
@interface LDClientManager (EventSourcePrivate)
    @property(nonatomic, strong, readonly) LDEventSource *eventSource;
@end

@implementation LDClientManager (EventSourcePrivate)
-(LDEventSource*)activeEventSource {
    return self.eventSource;
}
@end

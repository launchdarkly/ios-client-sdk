//
//  LDEnvironmentController+EventSource.h
//  Darkly
//
//  Created by Mark Pokorny on 8/2/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDEnvironmentController.h"
#import <DarklyEventSource/LDEventSource.h>

@interface LDEnvironmentController (EventSource)
-(LDEventSource*)eventSource;
@end

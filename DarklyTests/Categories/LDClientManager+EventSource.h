//
//  LDClientManager+EventSource.h
//  Darkly
//
//  Created by Mark Pokorny on 8/2/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>
#import "LDEventSource.h"

@interface LDClientManager (EventSource)
-(LDEventSource*)eventSource;
@end

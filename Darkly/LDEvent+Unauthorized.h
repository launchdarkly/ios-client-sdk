//
//  LDEvent+Unauthorized.h
//  Darkly
//
//  Created by Mark Pokorny on 10/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <DarklyEventSource/LDEventSource.h>

@interface LDEvent (Unauthorized)
- (BOOL)isUnauthorizedEvent;
@end

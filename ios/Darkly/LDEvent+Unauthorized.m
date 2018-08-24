//
//  LDEvent+Unauthorized.m
//  Darkly
//
//  Created by Mark Pokorny on 10/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDEvent+Unauthorized.h"
#import "DarklyConstants.h"

@implementation LDEvent (Unauthorized)
- (BOOL)isUnauthorizedEvent {
    NSError *error = self.error;
    return error && [error.domain isEqualToString:LDEventSourceErrorDomain] && error.code == kErrorCodeUnauthorized;
}
@end

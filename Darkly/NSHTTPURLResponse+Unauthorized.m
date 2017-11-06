//
//  NSHTTPURLResponse+Unauthorized.m
//  Darkly
//
//  Created by Mark Pokorny on 10/16/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSHTTPURLResponse+Unauthorized.h"
#import "DarklyConstants.h"

@implementation NSHTTPURLResponse(Unauthorized)
-(BOOL)isUnauthorizedHTTPResponse {
    return self.statusCode == kHTTPStatusCodeUnauthorized;
}
@end

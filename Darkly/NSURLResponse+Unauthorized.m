//
//  NSURLResponse+Unauthorized.m
//  Darkly
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSURLResponse+Unauthorized.h"
#import "NSHTTPURLResponse+Unauthorized.h"

@implementation NSURLResponse(Unauthorized)
-(BOOL)isUnauthorizedHTTPResponse {
    return NO;
}
@end

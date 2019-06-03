//
//  NSURLResponse+LaunchDarkly.m
//  Darkly
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSURLResponse+LaunchDarkly.h"
#import "NSHTTPURLResponse+LaunchDarkly.h"

@implementation NSURLResponse(LaunchDarkly)

-(BOOL)isOk {
    return NO;
}

-(BOOL)isNotModified {
    return NO;
}

-(BOOL)isUnauthorizedHTTPResponse {
    return NO;
}

-(NSDate*)headerDate {
    return nil;
}

-(NSString*)etag {
    return nil;
}

@end

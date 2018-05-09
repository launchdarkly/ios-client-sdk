//
//  NSURLResponse+LaunchDarkly.h
//  Darkly
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Determines if this response is an unauthorized HTTP response. By default NO, but can be overridden by subclasses that can detected unuathorized response.
@interface NSURLResponse(LaunchDarkly)
-(BOOL)isUnauthorizedHTTPResponse;
-(NSDate*)headerDate;
@end

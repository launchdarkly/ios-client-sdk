//
//  NSURLResponse+LaunchDarkly.h
//  Darkly
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLResponse(LaunchDarkly)
@property (assign, nonatomic, readonly) BOOL isOk;
@property (assign, nonatomic, readonly) BOOL isNotModified;
@property (copy, nonatomic, readonly) NSString *etag;

-(BOOL)isUnauthorizedHTTPResponse;
-(NSDate*)headerDate;
@end

//
//  NSHTTPURLResponse+LaunchDarkly.m
//  Darkly
//
//  Created by Mark Pokorny on 10/16/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSHTTPURLResponse+LaunchDarkly.h"
#import "DarklyConstants.h"
#import "NSDateFormatter+JsonHeader.h"

NSString * const kHeaderKeyDate = @"Date";
NSString * const kFlagResponseHeaderEtag = @"etag";

@implementation NSHTTPURLResponse(LaunchDarkly)

-(BOOL)isOk {
    return self.statusCode == kHTTPStatusCodeOk;
}

-(BOOL)isNotModified {
    return self.statusCode == kHTTPStatusCodeNotModified;
}

-(BOOL)isUnauthorizedHTTPResponse {
    return self.statusCode == kHTTPStatusCodeUnauthorized;
}

-(NSDate*)headerDate {
    NSString* headerDateString = [self allHeaderFields][kHeaderKeyDate];
    if (headerDateString.length == 0) { return nil; }
    return [[NSDateFormatter jsonHeaderDateFormatter] dateFromString:headerDateString];
}

-(NSString*)etag {
    return self.allHeaderFields[kFlagResponseHeaderEtag];
}
@end

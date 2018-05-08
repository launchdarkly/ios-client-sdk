//
//  NSDateFormatter+JsonHeader.m
//  Darkly
//
//  Created by Mark Pokorny on 5/8/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDateFormatter+JsonHeader.h"

@implementation NSDateFormatter(JsonHeader)
+(instancetype)jsonHeaderDateFormatter {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier: @"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";      //Mon, 07 May 2018 19:46:29 GMT

    return formatter;
}
@end

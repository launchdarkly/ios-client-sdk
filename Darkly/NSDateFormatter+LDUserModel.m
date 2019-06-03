//
//  NSDateFormatter+LDUserModel.m
//  Darkly
//
//  Created by Mark Pokorny on 12/21/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSDateFormatter+LDUserModel.h"

@implementation NSDateFormatter (LDUserModel)
+(instancetype)userDateFormatter {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    return formatter;
}
@end

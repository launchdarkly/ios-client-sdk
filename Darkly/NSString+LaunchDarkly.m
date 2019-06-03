//
//  NSString+LaunchDarkly.m
//  Darkly
//
//  Created by Mark Pokorny on 11/1/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSString+LaunchDarkly.h"

@implementation NSString (LaunchDarkly)
+(instancetype)stringWithBool:(BOOL)boolValue {
    return boolValue ? @"YES" : @"NO";
}
@end

//
//  NSDate+ReferencedDate.m
//  Darkly
//
//  Created by Mark Pokorny on 4/11/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSDate+ReferencedDate.h"

@implementation NSDate (ReferencedDate)
-(NSInteger)millisSince1970 {
    return [@(floor([self timeIntervalSince1970] * 1000)) integerValue];
}
@end

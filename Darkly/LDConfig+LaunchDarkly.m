//
//  LDConfig+LaunchDarkly.m
//  Darkly
//
//  Created by Mark Pokorny on 11/21/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDConfig+LaunchDarkly.h"

@implementation LDConfig (LaunchDarkly)
-(NSArray<NSString*>*)mobileKeys {
    NSMutableArray *keys = [NSMutableArray arrayWithArray:self.secondaryMobileKeys.allValues];
    [keys insertObject:self.mobileKey atIndex:0];
    return [keys copy];
}
@end

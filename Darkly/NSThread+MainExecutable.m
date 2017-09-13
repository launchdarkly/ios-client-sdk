//
//  NSThread+MainExecutable.m
//  Darkly
//
//  Created by Mark Pokorny on 8/9/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSThread+MainExecutable.h"

@implementation NSThread (MainExecutable)
+ (void)performOnMainThread:(void(^)(void))executionBlock {
    if (!executionBlock) { return; }
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(performOnMainThread:) withObject:executionBlock waitUntilDone:YES];
        return;
    }
    executionBlock();
}
@end

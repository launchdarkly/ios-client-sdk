//
//  NSThread+MainExecutable.h
//  Darkly
//
//  Created by Mark Pokorny on 8/9/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSThread (MainExecutable)
+ (void)performOnMainThread:(void(^)(void))executionBlock waitUntilDone:(BOOL)wait;
@end

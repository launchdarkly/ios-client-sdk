//
//  NSURLSession+LaunchDarkly.h
//  Darkly
//
//  Created by Mark Pokorny on 11/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDConfig;

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSession (LaunchDarkly)

+(void)setSharedLDSessionForConfig:(LDConfig*)config;
+(NSURLSession*)sharedLDSession;

@end

NS_ASSUME_NONNULL_END

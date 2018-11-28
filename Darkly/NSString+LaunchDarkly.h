//
//  NSString+LaunchDarkly.h
//  Darkly
//
//  Created by Mark Pokorny on 11/1/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (LaunchDarkly)
+(instancetype)stringWithBool:(BOOL)boolValue;

@end

NS_ASSUME_NONNULL_END

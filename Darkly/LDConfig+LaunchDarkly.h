//
//  LDConfig+LaunchDarkly.h
//  Darkly
//
//  Created by Mark Pokorny on 11/21/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface LDConfig (LaunchDarkly)
@property (nonatomic, strong, readonly) NSArray<NSString*> *mobileKeys;
@end

NS_ASSUME_NONNULL_END

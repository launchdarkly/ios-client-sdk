//
//  LDConfig+Testable.h
//  Darkly
//
//  Created by Mark Pokorny on 8/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDConfig (Testable)
@property (nonatomic, strong, nonnull, readonly) NSArray<NSNumber*> *flagRetryStatusCodes;
@end

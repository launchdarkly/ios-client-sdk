//
//  LDRequestManager+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 9/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDRequestManager (Testable)
@property (nonnull, nonatomic) LDConfig *config;
@end

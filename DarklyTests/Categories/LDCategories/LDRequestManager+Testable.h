//
//  LDRequestManager+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 9/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDRequestManager.h"

@interface LDRequestManager (Testable)
@property (nonnull, nonatomic) LDConfig *config;
@property (nullable, nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nullable, copy, nonatomic) NSString *featureFlagEtag;
@end

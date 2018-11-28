//
//  LDConfig+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDConfig.h"

extern NSString * const LDConfigTestEnvironmentNameMock;
extern NSString * const LDConfigTestSecondaryMobileKeyMock;

NS_ASSUME_NONNULL_BEGIN

@interface LDConfig (Testable)
@property (nonatomic, strong, nonnull) NSArray<NSNumber*> *flagRetryStatusCodes;
+(NSDictionary<NSString*,NSString*>*)secondaryMobileKeysStub;
@end

NS_ASSUME_NONNULL_END

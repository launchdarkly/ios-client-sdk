//
//  LDFlagValueCounter+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagValueCounter.h"

extern NSString * _Nonnull const kLDFlagValueCounterKeyValue;
extern NSString * _Nonnull const kLDFlagValueCounterKeyVersion;
extern NSString * _Nonnull const kLDFlagValueCounterKeyCount;
extern NSString * _Nonnull const kLDFlagValueCounterKeyUnknown;


@interface LDFlagValueCounter(Testable)
-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary* _Nullable)dictionary;
@end

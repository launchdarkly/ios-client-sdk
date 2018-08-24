//
//  LDFlagValueCounter+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagValueCounter.h"

extern NSString * const kLDFlagValueCounterKeyFlagConfigValue;
extern NSString * const kLDFlagValueCounterKeyValue;
extern NSString * const kLDFlagValueCounterKeyVersion;
extern NSString * const kLDFlagValueCounterKeyVariation;
extern NSString * const kLDFlagValueCounterKeyCount;
extern NSString * const kLDFlagValueCounterKeyUnknown;


@interface LDFlagValueCounter(Testable)
-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary;
@end

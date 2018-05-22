//
//  LDFlagCounter+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagCounter.h"

extern NSString * const kLDFlagCounterKeyDefaultValue;
extern NSString * const kLDFlagCounterKeyCounters;

@interface LDFlagCounter(Testable)
@property (nonatomic, strong) NSMutableArray<LDFlagValueCounter*> *flagValueCounters;

+(instancetype)stubForFlagKey:(NSString*)flagKey;
+(instancetype)stubForFlagKey:(NSString*)flagKey useKnownValues:(BOOL)useKnownValues;

@end

@interface LDFlagCounter (Private)
-(LDFlagValueCounter*)valueCounterForFlagConfigValue:(LDFlagConfigValue*)flagConfigValue;
@end

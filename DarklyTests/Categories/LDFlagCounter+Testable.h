//
//  LDFlagCounter+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagCounter.h"

@interface LDFlagCounter(Testable)
@property (nonatomic, strong) NSMutableArray<LDFlagValueCounter*> *flagValueCounters;

+(instancetype)stubForFlagKey:(NSString*)flagKey;
+(instancetype)stubForFlagKey:(NSString*)flagKey useKnownValues:(BOOL)useKnownValues;
-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary;

@end

@interface LDFlagCounter (Private)
-(LDFlagValueCounter*)valueCounterForFlagConfigValue:(LDFlagConfigValue*)flagConfigValue;
-(LDFlagValueCounter*)valueCounterForVariation:(NSInteger)variation;
-(LDFlagValueCounter*)valueCounterForValue:(id)value isKnownValue:(BOOL)isKnownValue;   //TODO: When variation is implemented, remove this
@end

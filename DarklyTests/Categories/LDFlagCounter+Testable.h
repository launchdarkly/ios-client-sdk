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
+(instancetype)stubForFlagKey:(NSString*)flagKey useUnknownValues:(BOOL)useUnknownValues;
-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary;
@end

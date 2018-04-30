//
//  LDFlagCounter.h
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagValueCounter.h"

@interface LDFlagCounter : NSObject
@property (nonatomic, strong, nonnull, readonly) NSString *flagKey;
@property (nonatomic, strong, nonnull) id defaultValue;
@property (nonatomic, strong, nonnull, readonly) NSArray<LDFlagValueCounter*> *valueCounters;

+(nonnull instancetype)counterWithFlagKey:(nonnull NSString*)flagKey defaultValue:(nonnull id)defaultValue;
-(nonnull instancetype)initWithFlagKey:(nonnull NSString*)flagKey defaultValue:(nonnull id)defaultValue;

-(void)logRequestWithValue:(nullable id)value version:(NSInteger)version variation:(NSInteger)variation defaultValue:(nullable id)defaultValue isKnownValue:(BOOL)isKnownValue;
-(nullable LDFlagValueCounter*)valueCounterForVariation:(NSInteger)variation;
-(nullable LDFlagValueCounter*)valueCounterForValue:(nonnull id)value isKnownValue:(BOOL)isKnownValue;   //TODO: When variation is implemented, remove this

-(nonnull NSDictionary*)dictionaryValue;

-(nonnull NSString*)description;
@end

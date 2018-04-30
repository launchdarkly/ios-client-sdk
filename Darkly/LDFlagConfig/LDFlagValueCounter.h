//
//  LDFlagValueCounter.h
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDFlagValueCounter : NSObject
@property (nonatomic, strong, nullable, readonly) id value;
@property (nonatomic, assign, readonly) NSInteger variation;
@property (nonatomic, assign, readonly) NSInteger version;
@property (nonatomic, assign, readonly, getter=isKnown) BOOL known;
@property (nonatomic, assign) NSInteger count;

+(nonnull instancetype)counterWithValue:(nullable id)value variation:(NSInteger)variation version:(NSInteger)version isKnownValue:(BOOL)isKnownValue;
-(nonnull instancetype)initWithValue:(nullable id)value variation:(NSInteger)variation version:(NSInteger)version isKnownValue:(BOOL)isKnownValue;

-(nonnull NSDictionary*)dictionaryValue;

-(nonnull NSString*)description;
@end

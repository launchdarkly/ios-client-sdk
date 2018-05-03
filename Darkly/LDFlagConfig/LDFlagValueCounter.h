//
//  LDFlagValueCounter.h
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagConfigValue;

@interface LDFlagValueCounter : NSObject
@property (nullable, nonatomic, strong, readonly) LDFlagConfigValue *flagConfigValue;
@property (nonatomic, assign, readonly, getter=isKnown) BOOL known;
@property (nonatomic, assign) NSInteger count;

+(nonnull instancetype)counterWithFlagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue;
-(nonnull instancetype)initWithFlagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue;

-(nonnull NSDictionary*)dictionaryValue;

-(nonnull NSString*)description;
@end

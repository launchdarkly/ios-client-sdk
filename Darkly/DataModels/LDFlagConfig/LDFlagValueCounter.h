//
//  LDFlagValueCounter.h
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagConfigValue;

@interface LDFlagValueCounter : NSObject <NSCopying>
@property (nonnull, nonatomic, strong) id reportedFlagValue;
@property (nullable, nonatomic, strong, readonly) LDFlagConfigValue *flagConfigValue;
@property (nonatomic, assign, readonly, getter=isKnown) BOOL known;
@property (nonatomic, assign) NSInteger count;

+(nonnull instancetype)counterWithFlagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue reportedFlagValue:(nonnull id)reportedFlagValue;
-(nonnull instancetype)initWithFlagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue reportedFlagValue:(nonnull id)reportedFlagValue;

-(nonnull NSDictionary*)dictionaryValue;

-(nonnull NSString*)description;
-(id)copyWithZone:(nullable NSZone*)zone;

@end

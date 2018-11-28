//
//  LDFlagCounter.h
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagValueCounter;
@class LDFlagConfigValue;

@interface LDFlagCounter : NSObject
@property (nonatomic, strong, nonnull, readonly) NSString *flagKey;
@property (nonatomic, strong, nonnull) id defaultValue;
@property (nonatomic, assign, readonly) BOOL hasLoggedRequests;

+(nonnull instancetype)counterWithFlagKey:(nonnull NSString*)flagKey defaultValue:(nonnull id)defaultValue;
-(nonnull instancetype)initWithFlagKey:(nonnull NSString*)flagKey defaultValue:(nonnull id)defaultValue;

-(void)logRequestWithFlagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue reportedFlagValue:(nonnull id)reportedFlagValue;

-(nonnull NSDictionary*)dictionaryValue;

-(nonnull NSString*)description;
@end

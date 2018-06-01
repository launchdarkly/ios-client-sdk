//
//  LDFlagConfigTracker.h
//  Darkly
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDate+ReferencedDate.h"

@class LDFlagCounter;
@class LDFlagConfigValue;

@interface LDFlagConfigTracker : NSObject
@property (nonatomic, assign, readonly) LDMillisecond startDateMillis;
@property (nonnull, nonatomic, strong, readonly) NSDictionary<NSString*, LDFlagCounter*> *flagCounters;

+(nonnull instancetype)tracker;
-(nonnull instancetype)init;

-(void)logRequestForFlagKey:(nonnull NSString*)flagKey
          reportedFlagValue:(nonnull id)reportedFlagValue
            flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
               defaultValue:(nullable id)defaultValue;

-(nonnull NSString*)description;
@end

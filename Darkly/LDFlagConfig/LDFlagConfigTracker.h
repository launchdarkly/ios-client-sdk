//
//  LDFlagConfigTracker.h
//  Darkly
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagCounter.h"

@interface LDFlagConfigTracker : NSObject
@property (nonatomic, assign, readonly) NSInteger startDateMillis;
@property (nonatomic, strong, readonly) NSDictionary<NSString*, LDFlagCounter*> * _Nonnull flagCounters;

+(instancetype _Nonnull)tracker;
-(instancetype _Nonnull)init;

-(void)logRequestForFlagKey:(NSString*_Nonnull)flagKey value:(id _Nullable)value version:(NSInteger)version variation:(NSInteger)variation defaultValue:(id _Nonnull)defaultValue;
@end

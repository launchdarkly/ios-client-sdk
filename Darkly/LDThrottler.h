//
//  LDThrottler.h
//  Darkly
//
//  Created by Mark Pokorny on 4/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDThrottler : NSObject
@property (nonatomic, assign, readonly) NSTimeInterval maxDelayInterval;
@property (nonatomic, assign, readonly) NSUInteger runAttempts;
@property (nonatomic, assign, readonly) NSTimeInterval delayInterval;
@property (nonatomic, strong, readonly) NSDate * _Nullable timerStartDate;
@property (nonatomic, strong, readonly) NSTimer * _Nullable delayTimer;

-(nullable instancetype)initWithMaxDelayInterval:(NSTimeInterval)maxDelaySeconds;
-(void)runThrottled:(void (^_Nonnull)(void))completion;
@end

//
//  LDThrottler.m
//  Darkly
//
//  Created by Mark Pokorny on 4/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDThrottler.h"
#import "DarklyConstants.h"
#import "LDUtil.h"

const NSTimeInterval minDelayInterval = 1.0;

@interface LDThrottler()
@property (nonatomic, assign) NSTimeInterval maxDelayInterval;
@property (nonatomic, assign) NSUInteger runAttempts;
@property (nonatomic, assign) NSTimeInterval delayInterval;
@property (nonatomic, strong) NSTimer *delayTimer;
@property (nonatomic, strong) NSDate *timerStartDate;
@property (nonatomic, strong) void(^runBlock)(void);
@property (nonatomic, strong) void(^timerFiredCallback)(void);
@end

@implementation LDThrottler
-(instancetype)initWithMaxDelayInterval:(NSTimeInterval)maxDelayInterval {
    if (!(self = [super init])) { return nil; }

    self.maxDelayInterval = maxDelayInterval > 0 && maxDelayInterval <= kMaxThrottlingDelayInterval ? maxDelayInterval : kMaxThrottlingDelayInterval;
    DEBUG_LOG(@"Throttler created with max delay: %0.2f", self.maxDelayInterval);

    return self;
}

-(void)runThrottled:(void (^)(void))runBlock {
    if (!runBlock) { return; }
    if (self.delayInterval == self.maxDelayInterval) {
        self.runAttempts += 1;
        self.runBlock = runBlock;
        DEBUG_LOG(@"Throttler delay interval at max. Allowing delay timer to expire. Run Attempts: %ld", (unsigned long)self.runAttempts);
        return;
    }

    @synchronized(self) {
        if (self.delayTimer) {
            [self.delayTimer invalidate];
        }
    }
    if (self.runAttempts == 0) {
        DEBUG_LOGX(@"Throttler executing run block on first attempt.");
        runBlock();
    } else {
        self.runBlock = runBlock;
    }

    self.runAttempts += 1;
    self.delayInterval = [self delayIntervalForRunAttempts:self.runAttempts];
    self.delayTimer = [self delayTimerWithDelayInterval:self.delayInterval];
    if (self.runAttempts > 1) {
        DEBUG_LOG(@"Throttler throttling run block. Run Attempts: %ld Delay: %0.2f", (unsigned long)self.runAttempts, self.delayInterval);
    }
}

-(NSTimeInterval)delayIntervalForRunAttempts:(NSUInteger)runAttempts {
    if (runAttempts > log2(self.maxDelayInterval)) { return self.maxDelayInterval; }
    double maxAttempts = log2(DBL_MAX);  //use to prevent overflowing
    NSTimeInterval exponentialBackoff = runAttempts < maxAttempts ? MIN(self.maxDelayInterval, minDelayInterval * pow(2, runAttempts)) : self.maxDelayInterval; // pow(x,y) returns x^y
    NSTimeInterval jitterBackoff = arc4random_uniform(exponentialBackoff);    // arc4random_uniform(upperBound) returns a double uniformly randomized between 0.0..<upperBound
    return exponentialBackoff / 2 + jitterBackoff / 2;  //half of each should yield [2^(runAttempts-1), 2^runAttempts)
}

-(NSTimer*)delayTimerWithDelayInterval:(NSUInteger)delaySeconds {
    if (!self.timerStartDate) {
        self.timerStartDate = [NSDate date];
    }
    NSDate *fireDate = [self.timerStartDate dateByAddingTimeInterval:delaySeconds];

    NSTimer *delayTimer = [[NSTimer alloc] initWithFireDate:fireDate interval:0 target:self selector:@selector(timerFired) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:delayTimer forMode:NSDefaultRunLoopMode];
    return delayTimer;
}

-(void)timerFired {
    @synchronized(self) {
        if (self.runAttempts > 1 && self.runBlock) {
            DEBUG_LOGX(@"Throttler delay timer fired, executing run block.");
            self.runBlock();
        }

        self.runAttempts = 0;
        self.delayInterval = 0.0;
        self.timerStartDate = nil;
        self.delayTimer = nil;
        self.runBlock = nil;

        if (!self.timerFiredCallback) { return; }
        self.timerFiredCallback();
        self.timerFiredCallback = nil;
    }
}

@end

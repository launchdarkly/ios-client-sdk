//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDPollingManager.h"
#import "LDUtil.h"
#import "DarklyConstants.h"
#import "NSNumber+LaunchDarkly.h"

@interface LDPollingManager()
@property (atomic, assign) PollingState flagConfigPollingState;
@property (atomic, assign) PollingState eventPollingState;

@property (strong, nonatomic) dispatch_source_t flagConfigTimer;
@property (strong, nonatomic) dispatch_source_t eventTimer;

@property (nonatomic, strong) LDConfig *config;

@property (nonatomic, assign) uint64_t flagConfigPollingIntervalNanos;
@property (nonatomic, assign) uint64_t eventPollingIntervalNanos;
@end

@implementation LDPollingManager
static LDPollingManager *sharedInstance = nil;

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static LDPollingManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.config = nil;
    });
    return sharedInstance;
}

- (id)init {
    if ((self = [super init])) {
        self.flagConfigPollingState = POLL_STOPPED;
        self.eventPollingState = POLL_STOPPED;
    }
    return self;
}

- (void)dealloc {
    [self stopFlagConfigPolling];
    [self stopEventPolling];
    
    _flagConfigPollingState = POLL_STOPPED;
    _eventPollingState = POLL_STOPPED;
}

#pragma mark - General Polling methods
-(void)setFireTimeForTimer:(dispatch_source_t)timer pollingIntervalNanos:(uint64_t)pollingIntervalNanos {
    if (timer == nil || pollingIntervalNanos <= 0) {
        return;
    }
    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, pollingIntervalNanos);
    dispatch_source_set_timer(timer, startTime, pollingIntervalNanos, 1.0);
}

#pragma mark - Config Polling methods
-(void)startFlagConfigPollingUsingConfig:(LDConfig*)config isOnline:(BOOL)isOnline {
    @synchronized(self) {
        if (!isOnline) {
            DEBUG_LOGX(@"PollingManager unable to start flag config polling because SDK is offline.");
            return;
        }
        if (self.flagConfigPollingState != POLL_STOPPED) {
            return; //This could be called multiple times for any given start attempt, only the first should succeed
        }

        self.flagConfigPollingState = POLL_STARTING;
        self.config = config;
        if ((self.flagConfigTimer == nil) && (self.flagConfigPollingIntervalNanos > 0.0)) {
            self.flagConfigTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        }
        if (self.flagConfigTimer == nil) {
            DEBUG_LOGX(@"PollingManager unable to create flagConfig timer.");
            self.flagConfigPollingState = POLL_STOPPED;
            return;
        }

        DEBUG_LOG(@"PollingManager starting flagConfig pollingwith pollingInterval=%f", (double)self.flagConfigPollingIntervalNanos / NSEC_PER_SEC);
        self.flagConfigPollingState = POLL_RUNNING;
        dispatch_source_set_event_handler(self.flagConfigTimer, ^(void) {
            [self flagConfigPoll];
        });
        [self setFireTimeForTimer:self.flagConfigTimer pollingIntervalNanos:self.flagConfigPollingIntervalNanos];
        dispatch_resume(self.flagConfigTimer);
    }
}

-(uint64_t)flagConfigPollingIntervalNanos {
    if (self.config == nil) {
        return  [@(kDefaultPollingInterval) nanoSecondValue];
    }
    //LDConfig precludes setting the pollingInterval below the min polling interval
    return [self.config.pollingInterval nanoSecondValue];
}

- (void)flagConfigPoll {
    @synchronized (self) {
        if (self.flagConfigPollingState != POLL_RUNNING) {
            DEBUG_LOGX(@"PollingManager flagConfig interval reached, but poll is not running. Aborting.");
            [self stopFlagConfigPolling];
            return;
        }

        DEBUG_LOGX(@"PollingManager flagConfig interval reached");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDFlagConfigTimerFiredNotification object:nil];
    }
}

- (void) suspendFlagConfigPolling {
    @synchronized(self) {
        if (self.flagConfigPollingState != POLL_RUNNING) {
            DEBUG_LOGX(@"PollingManager flagConfig polling is not running, unable to suspend");
            return;
        }
        DEBUG_LOGX(@"PollingManager suspending flagConfig polling");
        dispatch_suspend(self.flagConfigTimer);
        self.flagConfigPollingState = POLL_SUSPENDED;
    }
}

- (void) resumeFlagConfigPollingWhenIsOnline:(BOOL)isOnline {
    @synchronized (self) {
        if (!isOnline) {
            DEBUG_LOGX(@"PollingManager aborting resume flagConfig polling - sdk is offline");
            return;
        }
        if (self.flagConfigPollingState != POLL_SUSPENDED) {
            DEBUG_LOGX(@"PollingManager aborting resume flagConfig polling - poll is not suspended");
            return;
        }

        DEBUG_LOGX(@"PollingManager resuming flagConfig polling");
        dispatch_resume(self.flagConfigTimer);  //If the configTimer would have fired while suspended, it triggers a flag request
        self.flagConfigPollingState = POLL_RUNNING;
    }
}

- (void)stopFlagConfigPolling {
    @synchronized (self) {
        DEBUG_LOGX(@"PollingManager stopping flagConfig polling");
        if (self.flagConfigTimer != nil) {
            dispatch_source_cancel(self.flagConfigTimer);
            if (self.flagConfigPollingState == POLL_SUSPENDED) {
                dispatch_resume(self.flagConfigTimer);
            }
        }
        self.flagConfigTimer = nil;
        self.flagConfigPollingState = POLL_STOPPED;
    }
}

#pragma mark - Event Polling methods
- (void) startEventPollingUsingConfig:(LDConfig*)config isOnline:(BOOL)isOnline {
    @synchronized (self) {
        if (!isOnline) {
            DEBUG_LOGX(@"PollingManager unable to start event polling because SDK is offline.");
            return;
        }
        if (self.eventPollingState != POLL_STOPPED) {
            return;
        }

        self.eventPollingState = POLL_STARTING;
        self.config = config;
        if ((!self.eventTimer) && (self.eventPollingIntervalNanos > 0.0)) {
            self.eventTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        }
        if (self.eventTimer == nil) {
            DEBUG_LOGX(@"PollingManager unable to create event timer.");
            self.eventPollingState = POLL_STOPPED;
            return;
        }

        DEBUG_LOG(@"PollingManager starting event polling with pollingInterval=%f", (double)self.eventPollingIntervalNanos / NSEC_PER_SEC);
        self.eventPollingState = POLL_RUNNING;
        dispatch_source_set_event_handler(self.eventTimer, ^(void) {
            [self eventPoll];
        });
        [self setFireTimeForTimer:self.eventTimer pollingIntervalNanos:self.eventPollingIntervalNanos];
        dispatch_resume(self.eventTimer);
    }
}

-(uint64_t)eventPollingIntervalNanos {
    if (self.config == nil) { return  [@(kDefaultFlushInterval) nanoSecondValue]; }
    if (!self.config.streaming && [self.config.flushInterval isEqual:@(kDefaultFlushInterval)]) {
        return self.config.pollingInterval.nanoSecondValue;
    }
    if ([self.config.flushInterval intValue] <= kMinimumFlushInterval) {
        return [@(kMinimumFlushInterval) nanoSecondValue];
    }
    return [self.config.flushInterval nanoSecondValue];
}

- (void)eventPoll {
    @synchronized (self) {
        if (self.eventPollingState != POLL_RUNNING) {
            DEBUG_LOGX(@"PollingManager event interval reached, but poll is not running. Aborting.");
            [self stopEventPolling];
            return;
        }

        DEBUG_LOGX(@"PollingManager event interval reached");
        [[NSNotificationCenter defaultCenter] postNotificationName:kLDEventTimerFiredNotification object:nil];
    }
}

- (void) suspendEventPolling {
    @synchronized (self) {
        if (self.eventPollingState != POLL_RUNNING) {
            DEBUG_LOGX(@"PollingManager event polling is not running, unable to suspend");
            return;
        }
        DEBUG_LOGX(@"PollingManager suspending event polling");
        dispatch_suspend(self.eventTimer);
        self.eventPollingState = POLL_SUSPENDED;
    }
}

-(void)resumeEventPollingWhenIsOnline:(BOOL)isOnline {
    @synchronized (self) {
        if (!isOnline) {
            DEBUG_LOGX(@"PollingManager aborting resume event polling - sdk is offline");
            return;
        }
        if (self.eventPollingState != POLL_SUSPENDED) {
            DEBUG_LOGX(@"PollingManager aborting resume event polling - poll is not suspended");
            return;
        }

        DEBUG_LOGX(@"PollingManager resuming event polling");
        dispatch_resume(self.eventTimer);  //If the eventTimer would have fired while suspended, it triggers an event request
        self.eventPollingState = POLL_RUNNING;
    }
}

- (void)stopEventPolling {
    @synchronized (self) {
        DEBUG_LOGX(@"PollingManager stopping event polling");
        if (self.eventTimer != nil) {
            dispatch_source_cancel(self.eventTimer);
            if (self.eventPollingState == POLL_SUSPENDED) {
                dispatch_resume(self.eventTimer);
            }
        }
        self.eventTimer = nil;
        self.eventPollingState = POLL_STOPPED;
    }
}

@end

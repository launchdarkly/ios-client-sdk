//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDPollingManager.h"
#import "LDClientManager.h"
#import "LDUtil.h"
#import "DarklyConstants.h"

@implementation LDPollingManager

@synthesize pollingTimer;
@synthesize pollingIntervalMillis;
@synthesize pollingState;

static NSUInteger pollingCount=0;

static id sharedInstance = nil;

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    if ((self = [super init])) {
        pollingCount = 0;
        self.pollingState = POLL_STOPPED;
        self.pollingIntervalMillis = kDefaultFlushInterval*kMillisInSecs;
    }
    return self;
}

- (void)dealloc {
    [self stopPolling];
    pollingCount = 0;
    pollingState = POLL_STOPPED;
}

+ (NSUInteger)pollingCount {
    return pollingCount;
}

- (PollingState)pollingState {
    return pollingState;
}

//Setter method
- (void) setPollingIntervalMillis:(NSTimeInterval)eTimerPollingInterval {
    pollingIntervalMillis = [self calculateEventPollingIntervalMillis:eTimerPollingInterval];
    if (pollingState != POLL_STOPPED && pollingState != POLL_SUSPENDED) {
        // pause the event polling interval
        DEBUG_LOGX(@"Pausing event Polling");
        [self pausePolling];
        
        if (eTimerPollingInterval == kMinimumFlushIntervalMillis && [[[LDClient sharedInstance] ldConfig] debugEnabled] == YES) {
            [self poll];
        }
        
        [self updatePollingTimer];
        DEBUG_LOGX(@"updated event Polling");
        [self resumePolling];
        DEBUG_LOGX(@"resuming event Polling");
    }
}

-(NSTimeInterval)calculateEventPollingIntervalMillis:(NSTimeInterval)eTimerPollingInterval {
    LDConfig *config = [[LDClient sharedInstance] ldConfig];
    if (![config streaming] && [config pollingInterval]) {
        return [[[[LDClient sharedInstance] ldConfig] pollingInterval] doubleValue]*kMillisInSecs;
    }
    if (eTimerPollingInterval <= kMinimumFlushIntervalMillis) {
        return kDefaultFlushInterval*kMillisInSecs;
    } else {
        return eTimerPollingInterval;
    }
}


- (void)startPollTimer
{
    DEBUG_LOGX(@"PollingManager starting initial event polling");
    if ((!self.pollingTimer) && (self.pollingIntervalMillis > 0.0)) {
        self.pollingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    if (self.pollingTimer) {
        pollingState = POLL_RUNNING;
        
        dispatch_source_set_event_handler(self.pollingTimer, ^(void) {
            [self poll];
        });
        
        [self updatePollingTimer];
        dispatch_resume(self.pollingTimer);
    }
}

- (void)poll {
    if (pollingState != POLL_STOPPED || pollingState != POLL_SUSPENDED)
    {
        DEBUG_LOGX(@"PollingManager event interval reached");
        pollingCount +=1;
        
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager syncWithServerForEvents];
        if (![[[LDClient sharedInstance] ldConfig] streaming]) {
            [clientManager syncWithServerForConfig];
        }
    }
}

- (void)updatePollingTimer {
    if ((self.pollingTimer != NULL) && (self.pollingIntervalMillis > 0.0)) {
        uint64_t interval = (uint64_t)(self.pollingIntervalMillis * NSEC_PER_MSEC);
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
        dispatch_source_set_timer(self.pollingTimer, startTime, interval, 1.0);
    }
}


- (void) startPolling {
    if (pollingState == POLL_STOPPED) {
        DEBUG_LOGX(@"PollingManager starting event polling");
        [self startPollTimer];
    }
}

- (void) pausePolling {
    if (pollingState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager pausing event polling");
        dispatch_suspend(self.pollingTimer);
        pollingState = POLL_PAUSED;
    }
}

- (void) suspendPolling {
    if (pollingState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager suspending event polling");
        dispatch_suspend(self.pollingTimer);
        pollingState = POLL_SUSPENDED;
    }
}

- (void) resumePolling{
    if (pollingState == POLL_PAUSED || pollingState == POLL_SUSPENDED) {
        DEBUG_LOGX(@"PollingManager resuming event polling");
        BOOL checkEvent = pollingState == POLL_SUSPENDED ? YES : NO;
        dispatch_resume(self.pollingTimer);
        pollingState = POLL_RUNNING;
        if (checkEvent) {
            [self poll];
        }
    }
}

- (void)stopPolling {
    DEBUG_LOGX(@"PollingManager stopping event polling");
    if (self.pollingTimer) {
        dispatch_source_cancel(self.pollingTimer);

        if (pollingState == POLL_PAUSED || pollingState == POLL_SUSPENDED)
        {
            dispatch_resume(self.pollingTimer);
        }
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(self.pollingTimer);
#endif
        self.pollingTimer = NULL;
        pollingState = POLL_STOPPED;
    }
}


@end

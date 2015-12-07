//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDPollingManager.h"
#import "LDClientManager.h"
#import "LDUtil.h"
#import "DarklyConstants.h"

@implementation LDPollingManager


@synthesize configurationTimer;
@synthesize configurationTimerPollingInterval;
@synthesize eventTimer;
@synthesize eventTimerPollingInterval;
@synthesize pollConfigState;
@synthesize pollEventState;

static NSUInteger configPollingCount=0;
static NSUInteger eventPollingCount=0;

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
        self.configurationTimerPollingInterval = kDefaultConfigCheckInterval;
        self.eventTimerPollingInterval = kDefaultFlushInterval;
        configPollingCount = 0;
        eventPollingCount = 0;
        pollConfigState = POLL_STOPPED;
        pollEventState = POLL_STOPPED;
    }
    return self;
}

- (void)dealloc {
    [self stopConfigPolling];
    [self stopEventPolling];
    configPollingCount = 0;
    eventPollingCount = 0;
    pollConfigState = POLL_STOPPED;
    pollEventState = POLL_STOPPED;
}

//Setter method
- (void) setConfigurationTimerPollingInterval:(NSTimeInterval)cTimerPollingInterval {
    configurationTimerPollingInterval = [self calculateConfigPollingInterval:cTimerPollingInterval];
    if (pollConfigState != POLL_STOPPED && pollConfigState != POLL_SUSPENDED) {
        // pause the config polling interval
        DEBUG_LOGX(@"Pausing config Polling");
        [self pauseConfigPolling];
        
        if (cTimerPollingInterval == kMinimumPollingInterval && [[[LDClient sharedInstance] ldConfig] debugEnabled] == YES) {
            [self configPoll];
        }
        
        [self updateConfigPollingTimer];
        DEBUG_LOGX(@"updated config Polling");
        [self resumeConfigPolling];
        DEBUG_LOGX(@"resuming config Polling");
    }

}

-(NSTimeInterval)calculateConfigPollingInterval:(NSTimeInterval)cTimerPollingInterval {
    if (cTimerPollingInterval == kMinimumPollingInterval) {
        return kDefaultConfigCheckInterval;
    } else {
        return cTimerPollingInterval;
    }
}

- (void)startConfigTimer {
    DEBUG_LOGX(@"PollingManager starting initial config polling");
    if ((!self.configurationTimer) && (self.configurationTimerPollingInterval > 0.0)) {
        self.configurationTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    if (self.configurationTimer) {
        pollConfigState = POLL_RUNNING;
        
        dispatch_source_set_event_handler(self.configurationTimer, ^(void) {
            [self configPoll];
        });
        
        // should not be able to modify the configuration timer
        [self updateConfigPollingTimer];
        dispatch_resume(self.configurationTimer);
    }
}

- (void)updateConfigPollingTimer {
    if ((self.configurationTimer != NULL) && (self.configurationTimerPollingInterval > 0.0)) {
        uint64_t interval = (uint64_t)(self.configurationTimerPollingInterval * NSEC_PER_SEC);
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
        dispatch_source_set_timer(self.configurationTimer, startTime, interval, 1.0);
    }
}

- (void)configPoll {
    
    if (pollConfigState != POLL_STOPPED || pollConfigState != POLL_SUSPENDED)
    {
      DEBUG_LOGX(@"PollingManager config interval reached");
      configPollingCount +=1;
    
      LDClientManager *clientManager = [LDClientManager sharedInstance];
      [clientManager syncWithServerForConfig];
    }
}

+ (NSUInteger)configPollingCount {
    return configPollingCount;
}

+ (NSUInteger)eventPollingCount {
    return eventPollingCount;
}

- (PollingState)configPollingState {
    return pollConfigState;
}

- (PollingState)eventPollingState {
    return pollEventState;
}

- (void) startConfigPolling {
    if (pollConfigState == POLL_STOPPED) {
        DEBUG_LOGX(@"PollingManager starting config polling");
        [self startConfigTimer];
    }
}

- (void) pauseConfigPolling {
    if (pollConfigState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager pausing config polling");
        dispatch_suspend(self.configurationTimer);
        pollConfigState = POLL_PAUSED;
    }
}

- (void) suspendConfigPolling {
    if (pollConfigState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager suspending config polling");
        dispatch_suspend(self.configurationTimer);
        pollConfigState = POLL_SUSPENDED;
    }
}

- (void) resumeConfigPolling{
    if (pollConfigState == POLL_PAUSED || pollConfigState == POLL_SUSPENDED) {
        DEBUG_LOGX(@"PollingManager resuming config polling");
        BOOL checkConfig = pollConfigState == POLL_SUSPENDED ? YES : NO;
        dispatch_resume(self.configurationTimer);
        pollConfigState = POLL_RUNNING;
        if (checkConfig) {
            [self configPoll];
        }
    }
}

- (void)stopConfigPolling {
    DEBUG_LOGX(@"PollingManager stopping config polling");
    if (self.configurationTimer) {
        dispatch_source_cancel(self.configurationTimer);

        if (pollConfigState == POLL_PAUSED)
            dispatch_resume(self.configurationTimer);

#if !OS_OBJECT_USE_OBJC
        dispatch_release(self.configurationTimer);
#endif
       if(self.configurationTimer != nil)
            self.configurationTimer = nil;
  
        pollConfigState = POLL_STOPPED;
    }
}

//Setter method
- (void) setEventTimerPollingInterval:(NSTimeInterval)eTimerPollingInterval {
    eventTimerPollingInterval = [self calculateEventPollingInterval:eTimerPollingInterval];
    if (pollEventState != POLL_STOPPED && pollEventState != POLL_SUSPENDED) {
        // pause the event polling interval
        DEBUG_LOGX(@"Pausing event Polling");
        [self pauseEventPolling];
        
        if (eTimerPollingInterval == kMinimumPollingInterval && [[[LDClient sharedInstance] ldConfig] debugEnabled] == YES) {
            [self eventPoll];
        }
        
        [self updateEventPollingTimer];
        DEBUG_LOGX(@"updated event Polling");
        [self resumeEventPolling];
        DEBUG_LOGX(@"resuming event Polling");
    }
    
}

-(NSTimeInterval)calculateEventPollingInterval:(NSTimeInterval)eTimerPollingInterval {
    if (eTimerPollingInterval == kMinimumPollingInterval) {
        return kDefaultFlushInterval;
    } else {
        return eTimerPollingInterval;
    }
}


- (void)startEventPollTimer
{
    DEBUG_LOGX(@"PollingManager starting initial event polling");
    if ((!self.eventTimer) && (self.eventTimerPollingInterval > 0.0)) {
        self.eventTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    if (self.eventTimer) {
        pollEventState = POLL_RUNNING;
        
        dispatch_source_set_event_handler(self.eventTimer, ^(void) {
            
            [self eventPoll];
            
        });
        
        [self updateEventPollingTimer];
        dispatch_resume(self.eventTimer);
    }
}

- (void)eventPoll {
    if (pollEventState != POLL_STOPPED || pollEventState != POLL_SUSPENDED)
    {
        DEBUG_LOGX(@"PollingManager event interval reached");
        eventPollingCount +=1;
        
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager syncWithServerForEvents];
    }
}

- (void)updateEventPollingTimer {
    if ((self.eventTimer != NULL) && (self.eventTimerPollingInterval > 0.0)) {
        uint64_t interval = (uint64_t)(self.eventTimerPollingInterval * NSEC_PER_SEC);
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
        dispatch_source_set_timer(self.eventTimer, startTime, interval, 1.0);
    }
}


- (void) startEventPolling {
    if (pollEventState == POLL_STOPPED) {
        DEBUG_LOGX(@"PollingManager starting event polling");
        [self startEventPollTimer];
    }
}

- (void) pauseEventPolling {
    if (pollEventState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager pausing event polling");
        dispatch_suspend(self.eventTimer);
        pollEventState = POLL_PAUSED;
    }
}

- (void) suspendEventPolling {
    if (pollEventState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager suspending event polling");
        dispatch_suspend(self.eventTimer);
        pollEventState = POLL_SUSPENDED;
    }
}

- (void) resumeEventPolling{
    if (pollEventState == POLL_PAUSED || pollEventState == POLL_SUSPENDED) {
        DEBUG_LOGX(@"PollingManager resuming event polling");
        BOOL checkEvent = pollEventState == POLL_SUSPENDED ? YES : NO;
        dispatch_resume(self.eventTimer);
        pollEventState = POLL_RUNNING;
        if (checkEvent) {
            [self eventPoll];
        }
    }
}

- (void)stopEventPolling {
    DEBUG_LOGX(@"PollingManager stopping event polling");
    if (self.eventTimer) {
        dispatch_source_cancel(self.eventTimer);

        if (pollEventState == POLL_PAUSED)
        {
            dispatch_resume(self.eventTimer);
        }
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(self.eventTimer);
#endif
        self.eventTimer = NULL;
        pollEventState = POLL_STOPPED;
    }
}



@end

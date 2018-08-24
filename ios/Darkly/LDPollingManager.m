//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDPollingManager.h"
#import "LDClientManager.h"
#import "LDUtil.h"
#import "DarklyConstants.h"

@implementation LDPollingManager

@synthesize eventTimer;
@synthesize eventPollingIntervalMillis;
@synthesize eventPollingState;
@synthesize configTimer;
@synthesize configPollingIntervalMillis;
@synthesize configPollingState;

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
        self.configPollingState = POLL_STOPPED;
        self.eventPollingState = POLL_STOPPED;
        
        self.configPollingIntervalMillis = kDefaultPollingInterval*kMillisInSecs;
        self.eventPollingIntervalMillis = kDefaultFlushInterval*kMillisInSecs;
    }
    return self;
}

- (void)dealloc {
    [self stopConfigPolling];
    [self stopEventPolling];
    
    configPollingState = POLL_STOPPED;
    eventPollingState = POLL_STOPPED;
}

#pragma mark - Config Polling methods

- (void)startConfigPollTimer
{
    DEBUG_LOGX(@"PollingManager starting initial config polling");
    if ((!self.configTimer) && (self.configPollingIntervalMillis > 0.0)) {
        self.configTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    if (self.configTimer) {
        configPollingState = POLL_RUNNING;
        
        dispatch_source_set_event_handler(self.configTimer, ^(void) {
            [self configPoll];
        });
        
        [self updateConfigPollingTimer];
        dispatch_resume(self.configTimer);
    }
}

- (void)configPoll {
    @synchronized (self) {
    if (configPollingState != POLL_STOPPED || configPollingState != POLL_SUSPENDED)
    {
        DEBUG_LOGX(@"PollingManager config interval reached");
        
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        if (![[[LDClient sharedInstance] ldConfig] streaming]) {
            [clientManager syncWithServerForConfig];
        }
    }
    }
}

- (void)updateConfigPollingTimer {
    if ((self.configTimer != NULL) && (self.configPollingIntervalMillis > 0.0)) {
        uint64_t interval = (uint64_t)(self.configPollingIntervalMillis * NSEC_PER_MSEC);
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
        dispatch_source_set_timer(self.configTimer, startTime, interval, 1.0);
    }
}

- (void) startConfigPolling {
    self.configPollingIntervalMillis = [[LDClient sharedInstance].ldConfig.pollingInterval intValue] * kMillisInSecs;
    if (![LDClientManager sharedInstance].isOnline) {
        DEBUG_LOGX(@"PollingManager aborting start config polling - client offline");
        return;
    }
    if (configPollingState == POLL_STOPPED) {
        DEBUG_LOGX(@"PollingManager starting config polling");
        [self startConfigPollTimer];
    }
}

- (void) pauseConfigPolling {
    if (configPollingState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager pausing config polling");
        dispatch_suspend(self.configTimer);
        configPollingState = POLL_PAUSED;
    }
}

- (void) suspendConfigPolling {
    if (configPollingState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager suspending config polling");
        dispatch_suspend(self.configTimer);
        configPollingState = POLL_SUSPENDED;
    }
}

- (void) resumeConfigPolling{
    if (configPollingState != POLL_PAUSED && configPollingState != POLL_SUSPENDED) {
        DEBUG_LOGX(@"PollingManager aborting resume config polling - poll not paused or suspended");
        return;
    }

    if (![LDClientManager sharedInstance].isOnline) {
        DEBUG_LOGX(@"PollingManager aborting resume config polling - client offline");
        return;
    }

    DEBUG_LOGX(@"PollingManager resuming config polling");
    dispatch_resume(self.configTimer);  //If the configTimer would have fired while paused/suspended, it triggers a flag request
    @synchronized (self) {
        configPollingState = POLL_RUNNING;
    }
}

- (void)stopConfigPolling {
    DEBUG_LOGX(@"PollingManager stopping config polling");
    if (self.configTimer) {
        dispatch_source_cancel(self.configTimer);
        
        if (configPollingState == POLL_PAUSED || configPollingState == POLL_SUSPENDED)
        {
            dispatch_resume(self.configTimer);
        }
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(self.pollingTimer);
#endif
        self.configTimer = NULL;
        configPollingState = POLL_STOPPED;
    }
}

#pragma mark - Event Polling methods
//Setter method
- (void) setEventPollingIntervalMillis:(NSTimeInterval)eTimerPollingInterval {
    eventPollingIntervalMillis = [self calculateEventPollingIntervalMillis:eTimerPollingInterval];
    if (eventPollingState != POLL_STOPPED && eventPollingState != POLL_SUSPENDED) {
        // pause the event polling interval
        DEBUG_LOGX(@"Pausing event Polling");
        [self pauseEventPolling];
        
        if (eTimerPollingInterval == kMinimumFlushIntervalMillis && [[[LDClient sharedInstance] ldConfig] debugEnabled] == YES) {
            [self eventPoll];
        }
        
        [self updateEventPollingTimer];
        DEBUG_LOGX(@"updated event Polling");
        [self resumeEventPolling];
        DEBUG_LOGX(@"resuming event Polling");
    }
}

-(NSTimeInterval)calculateEventPollingIntervalMillis:(NSTimeInterval)eTimerPollingInterval {
    LDConfig *config = [[LDClient sharedInstance] ldConfig];
    if (![config streaming] && [[config flushInterval] intValue] == kDefaultFlushInterval) {
        return [config.pollingInterval intValue] * kMillisInSecs;
    }
    if (eTimerPollingInterval <= kMinimumFlushIntervalMillis) {
        return kDefaultFlushInterval*kMillisInSecs;
    } else {
        return eTimerPollingInterval;
    }
}


- (void)startEventPollTimer
{
    DEBUG_LOGX(@"PollingManager starting initial event polling");
    if ((!self.eventTimer) && (self.eventPollingIntervalMillis > 0.0)) {
        self.eventTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    if (self.eventTimer) {
        eventPollingState = POLL_RUNNING;
        
        dispatch_source_set_event_handler(self.eventTimer, ^(void) {
            [self eventPoll];
        });
        
        [self updateEventPollingTimer];
        dispatch_resume(self.eventTimer);
    }
}

- (void)eventPoll {
    @synchronized (self) {
        if (eventPollingState != POLL_STOPPED || eventPollingState != POLL_SUSPENDED)
        {
            DEBUG_LOGX(@"PollingManager event interval reached");
            
            LDClientManager *clientManager = [LDClientManager sharedInstance];
            [clientManager syncWithServerForEvents];
        }
    }
}

- (void)updateEventPollingTimer {
    if ((self.eventTimer != NULL) && (self.eventPollingIntervalMillis > 0.0)) {
        uint64_t interval = (uint64_t)(self.eventPollingIntervalMillis * NSEC_PER_MSEC);
        dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, interval);
        dispatch_source_set_timer(self.eventTimer, startTime, interval, 1.0);
    }
}

- (void) startEventPolling {
    self.eventPollingIntervalMillis = [[[LDClient sharedInstance] ldConfig].flushInterval intValue] * kMillisInSecs;
    if (![LDClientManager sharedInstance].isOnline) {
        DEBUG_LOGX(@"PollingManager aborting start event polling - client offline");
        return;
    }
    if (eventPollingState == POLL_STOPPED) {
        DEBUG_LOG(@"PollingManager starting event polling with pollingInterval=%f", self.eventPollingIntervalMillis);
        [self startEventPollTimer];
    }
}

- (void) pauseEventPolling {
    if (eventPollingState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager pausing event polling");
        dispatch_suspend(self.eventTimer);
        eventPollingState = POLL_PAUSED;
    }
}

- (void) suspendEventPolling {
    if (eventPollingState == POLL_RUNNING) {
        DEBUG_LOGX(@"PollingManager suspending event polling");
        dispatch_suspend(self.eventTimer);
        eventPollingState = POLL_SUSPENDED;
    }
}

- (void) resumeEventPolling{
    if (eventPollingState != POLL_PAUSED && eventPollingState != POLL_SUSPENDED) {
        DEBUG_LOGX(@"PollingManager aborting resume event polling - poll is neither paused nor started");
        return;
    }

    if (![LDClientManager sharedInstance].isOnline) {
        DEBUG_LOGX(@"PollingManager aborting resume event polling - client offline");
        return;
    }
    
    DEBUG_LOGX(@"PollingManager resuming event polling");
    BOOL checkEvent = eventPollingState == POLL_SUSPENDED ? YES : NO;
    dispatch_resume(self.eventTimer);
    @synchronized (self) {
        eventPollingState = POLL_RUNNING;
    }
    if (checkEvent) {
        [self eventPoll];
    }
}

- (void)stopEventPolling {
    DEBUG_LOGX(@"PollingManager stopping event polling");
    if (self.eventTimer) {
        dispatch_source_cancel(self.eventTimer);

        if (eventPollingState == POLL_PAUSED || eventPollingState == POLL_SUSPENDED)
        {
            dispatch_resume(self.eventTimer);
        }
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(self.pollingTimer);
#endif
        self.eventTimer = NULL;
        eventPollingState = POLL_STOPPED;
    }
}


@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


typedef enum {
    POLL_STOPPED = 0,
    POLL_PAUSED = 1,
    POLL_RUNNING = 2,
    POLL_SUSPENDED = 3,
    
} PollingState;

@interface LDPollingManager : NSObject
{
@protected
    PollingState pollEventState;
}


+ (id)sharedInstance;
@property (nonatomic, assign) PollingState pollEventState;

@property (strong, nonatomic) dispatch_source_t eventTimer;
@property (nonatomic) NSTimeInterval eventTimerPollingIntervalMillis;

+ (NSUInteger)eventPollingCount;

// event polling is passed in from the LDClient object. can be modified...
- (void) startEventPolling;
- (void) pauseEventPolling;
- (void) suspendEventPolling;
- (void) resumeEventPolling;
- (void) stopEventPolling;
- (PollingState)eventPollingState;

@end
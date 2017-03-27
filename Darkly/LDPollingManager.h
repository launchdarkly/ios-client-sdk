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
    PollingState pollingState;
}


+ (id)sharedInstance;
@property (nonatomic, assign) PollingState pollingState;

@property (strong, nonatomic) dispatch_source_t pollingTimer;
@property (nonatomic) NSTimeInterval pollingIntervalMillis;

+ (NSUInteger)pollingCount;

// event polling is passed in from the LDClient object. can be modified...
- (void) startPolling;
- (void) pausePolling;
- (void) suspendPolling;
- (void) resumePolling;
- (void) stopPolling;
- (PollingState)pollingState;

@end

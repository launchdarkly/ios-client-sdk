//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    POLL_STOPPED = 0,
    POLL_PAUSED = 1,
    POLL_RUNNING = 2,
    POLL_SUSPENDED = 3,
    
} PollingState;

@interface LDPollingManager : NSObject
{
@protected
    PollingState configPollingState;
    PollingState eventPollingState;
}


+ (id)sharedInstance;
@property (atomic, assign) PollingState configPollingState;
@property (atomic, assign) PollingState eventPollingState;

@property (strong, nonatomic) dispatch_source_t configTimer;
@property (nonatomic) NSTimeInterval configPollingIntervalMillis;
@property (strong, nonatomic) dispatch_source_t eventTimer;
@property (nonatomic) NSTimeInterval eventPollingIntervalMillis;

- (void) startConfigPolling;
- (void) pauseConfigPolling;
- (void) suspendConfigPolling;
- (void) resumeConfigPolling;
- (void) stopConfigPolling;
- (PollingState)configPollingState;

// event polling is passed in from the LDClient object. can be modified...
- (void) startEventPolling;
- (void) pauseEventPolling;
- (void) suspendEventPolling;
- (void) resumeEventPolling;
- (void) stopEventPolling;
- (PollingState)eventPollingState;

@end

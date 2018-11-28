//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDConfig.h"

typedef enum {
    POLL_STOPPED = 0,
    POLL_STARTING = 1,
    POLL_RUNNING = 2,
    POLL_SUSPENDED = 3,
    
} PollingState;

@interface LDPollingManager : NSObject

+ (LDPollingManager*)sharedInstance;
@property (atomic, assign, readonly) PollingState flagConfigPollingState;
@property (atomic, assign, readonly) PollingState eventPollingState;

@property (strong, nonatomic, readonly) dispatch_source_t flagConfigTimer;
@property (strong, nonatomic, readonly) dispatch_source_t eventTimer;

@property (nonatomic, strong, readonly) LDConfig *config;

- (void) startFlagConfigPollingUsingConfig:(LDConfig*)config isOnline:(BOOL)isOnline;
- (void) suspendFlagConfigPolling;
- (void) resumeFlagConfigPollingWhenIsOnline:(BOOL)isOnline;
- (void) stopFlagConfigPolling;
- (PollingState)flagConfigPollingState;

///The LDPollingManager has no way to determine if the SDK is online. Verify the SDK is online prior to starting event polling
- (void) startEventPollingUsingConfig:(LDConfig*)config isOnline:(BOOL)isOnline;
- (void) suspendEventPolling;
- (void) resumeEventPollingWhenIsOnline:(BOOL)isOnline;
- (void) stopEventPolling;
- (PollingState)eventPollingState;

@end

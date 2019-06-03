//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDPollingManager.h"
#import "LDConfig.h"
#import "OCMock.h"
#import "NSNumber+LaunchDarkly.h"

extern NSString *const kTestMobileKey;
NSString *const kAlternateMobileKey = @"alternateMobileKey";

@interface LDPollingManager (Testable)
-(uint64_t)flagConfigPollingIntervalNanos;
-(uint64_t)eventPollingIntervalNanos;
-(void)flagConfigPoll;
-(void)eventPoll;
@end

@interface LDPollingManagerTest : DarklyXCTestCase
@end

@implementation LDPollingManagerTest
- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    [[LDPollingManager sharedInstance] stopEventPolling];
    [super tearDown];
}

- (void)testFlagConfigPollingStates {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendFlagConfigPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_STOPPED);
}

- (void)testFlagConfigPollingState_suspendPolling_notRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;

    [[LDPollingManager sharedInstance] suspendFlagConfigPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_STOPPED);
}

- (void)testFlagConfigPollingState_resumePolling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendFlagConfigPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] resumeFlagConfigPollingWhenIsOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_RUNNING);
}

- (void)testFlagConfigPollingState_stopPolling_pollRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_STOPPED);
}

- (void)testEventPollingStates {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendEventPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] stopEventPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_STOPPED);
}

- (void)testEventPollingState_suspendPolling_notRunning {
    [[LDPollingManager sharedInstance] suspendEventPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_STOPPED);
}

- (void)testEventPollingState_resumePolling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendEventPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] resumeEventPollingWhenIsOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);
}

- (void)testEventPollingState_stopPolling_pollRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopEventPolling];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_STOPPED);
}

-(void)testPollingInterval_defaultConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_RUNNING);
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kDefaultFlushInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] eventPollingState], POLL_RUNNING);
    [[LDPollingManager sharedInstance] stopEventPolling];
}

-(void)testPollingInterval_belowMinima {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    config.pollingInterval = @(kMinimumPollingInterval - 1);    //config prevents this, and instead sets the min polling interval
    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kMinimumPollingInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];

    config.flushInterval = @(kMinimumFlushInterval - 1);
    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kMinimumFlushInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    [[LDPollingManager sharedInstance] stopEventPolling];
}

-(void)testPollingInterval_atMinima {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    config.pollingInterval = @(kMinimumPollingInterval);
    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [config.pollingInterval nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];

    config.flushInterval = @(kMinimumFlushInterval);
    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [config.flushInterval nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    [[LDPollingManager sharedInstance] stopEventPolling];
}

- (void)testPollingInterval_justAboveMinima {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    config.pollingInterval = [NSNumber numberWithInt:kMinimumPollingInterval + 1];
    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [config.pollingInterval nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];

    config.flushInterval = [NSNumber numberWithInt:50];
    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [config.flushInterval nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    [[LDPollingManager sharedInstance] stopEventPolling];
}

-(void)testPollingInterval_noConfig {
    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:nil isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);
    XCTAssertNil([LDPollingManager sharedInstance].config);
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_RUNNING);
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:nil isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kDefaultFlushInterval) nanoSecondValue]);
    XCTAssertEqual([[LDPollingManager sharedInstance] eventPollingState], POLL_RUNNING);
    [[LDPollingManager sharedInstance] stopEventPolling];
}

-(void)testPollingInterval_pollingModeDefaultEventPollingInterval {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_RUNNING);
    [[LDPollingManager sharedInstance] stopFlagConfigPolling];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);    //Event polling interval matches flagConfig polling interval
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] eventPollingState], POLL_RUNNING);
    [[LDPollingManager sharedInstance] stopEventPolling];
}

- (void)testFlagConfigPolling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_STOPPED);
}

-(void)testStartFlagConfigPolling_offline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:NO];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_STOPPED);
}

- (void)testResumeFlagConfigPolling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendFlagConfigPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] resumeFlagConfigPollingWhenIsOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_STOPPED);
}

- (void)testResumeFlagConfigPolling_pollStopped {
    [[LDPollingManager sharedInstance] resumeFlagConfigPollingWhenIsOnline:YES];

    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_STOPPED);
}

- (void)testResumeFlagConfigPolling_pollRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] resumeFlagConfigPollingWhenIsOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_RUNNING);
}

- (void)testResumeFlagConfigPolling_offline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendFlagConfigPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] resumeFlagConfigPollingWhenIsOnline:NO];
    XCTAssertTrue([LDPollingManager sharedInstance].flagConfigPollingState == POLL_SUSPENDED);
}

- (void)testEventPolling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopEventPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_STOPPED);
}

-(void)testStartEventPolling_offline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:NO];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_STOPPED);
}

- (void)testResumeEventPolling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendEventPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] resumeEventPollingWhenIsOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopEventPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_STOPPED);
}

- (void)testResumeEventPolling_offline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] suspendEventPolling];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_SUSPENDED);

    [[LDPollingManager sharedInstance] resumeEventPollingWhenIsOnline:NO];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_SUSPENDED);
}

- (void)testResumeEventPolling_pollStopped {
    [[LDPollingManager sharedInstance] resumeEventPollingWhenIsOnline:YES];

    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_STOPPED);
}

- (void)testResumeEventPolling_pollRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_RUNNING);

    [[LDPollingManager sharedInstance] resumeEventPollingWhenIsOnline:YES];
    XCTAssertTrue([LDPollingManager sharedInstance].eventPollingState == POLL_RUNNING);
}


- (void)testFlagConfigPoll {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;
    id flagConfigTimerFiredObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:flagConfigTimerFiredObserver name:kLDFlagConfigTimerFiredNotification object:nil];
    [[flagConfigTimerFiredObserver expect] notificationWithName: kLDFlagConfigTimerFiredNotification object:nil];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:flagConfigTimerFiredObserver];
    };
    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] flagConfigPoll];

    [flagConfigTimerFiredObserver verify];
}

- (void)testFlagConfigPoll_pollNotRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    config.streaming = NO;
    id flagConfigTimerFiredObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:flagConfigTimerFiredObserver name:kLDFlagConfigTimerFiredNotification object:nil];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:flagConfigTimerFiredObserver];
    };

    [[LDPollingManager sharedInstance] flagConfigPoll];

    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingState, POLL_STOPPED);
    [flagConfigTimerFiredObserver verify];
}

- (void)testEventPoll {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    id eventTimerFiredObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:eventTimerFiredObserver name:kLDEventTimerFiredNotification object:nil];
    [[eventTimerFiredObserver expect] notificationWithName: kLDEventTimerFiredNotification object:[OCMArg any]];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:eventTimerFiredObserver];
    };
    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] eventPoll];

    [eventTimerFiredObserver verify];
}

- (void)testEventPoll_pollNotRunning {
    id eventTimerFiredObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:eventTimerFiredObserver name:kLDEventTimerFiredNotification object:nil];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:eventTimerFiredObserver];
    };

    [[LDPollingManager sharedInstance] eventPoll];

    [eventTimerFiredObserver verify];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_STOPPED);
}

- (void)testStartFlagConfigPollingUsingConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];

    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_RUNNING);
}

- (void)testStartFlagConfigPollingUsingConfig_pollRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:config isOnline:YES];

    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_RUNNING);

    //Once the poll is running, it shouldn't start again until it's been stopped
    LDConfig *altConfig = [[LDConfig alloc] initWithMobileKey:kAlternateMobileKey];
    [[LDPollingManager sharedInstance] startFlagConfigPollingUsingConfig:altConfig isOnline:YES];

    XCTAssertEqual([LDPollingManager sharedInstance].flagConfigPollingIntervalNanos, [@(kDefaultPollingInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopFlagConfigPolling];
    XCTAssertEqual([[LDPollingManager sharedInstance] flagConfigPollingState], POLL_STOPPED);
}

- (void)testStartEventPollingUsingConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];

    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kDefaultFlushInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);
}

- (void)testStartEventPollingUsingConfig_pollRunning {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:config isOnline:YES];
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kDefaultFlushInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);

    //Once the poll is running, it shouldn't start again until it's been stopped
    LDConfig *altConfig = [[LDConfig alloc] initWithMobileKey:kAlternateMobileKey];
    [[LDPollingManager sharedInstance] startEventPollingUsingConfig:altConfig isOnline:YES];

    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingIntervalNanos, [@(kDefaultFlushInterval) nanoSecondValue]);
    XCTAssertEqualObjects([LDPollingManager sharedInstance].config, config);
    XCTAssertEqual([LDPollingManager sharedInstance].eventPollingState, POLL_RUNNING);

    [[LDPollingManager sharedInstance] stopEventPolling];
    XCTAssertEqual([[LDPollingManager sharedInstance] eventPollingState], POLL_STOPPED);
}

@end

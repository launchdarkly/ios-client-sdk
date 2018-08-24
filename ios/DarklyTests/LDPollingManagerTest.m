//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDPollingManager.h"
#import "LDClientManager.h"
#import "LDConfig.h"
#import "LDClient.h"
#import "OCMock.h"

extern NSString *const kTestMobileKey;

@interface LDPollingManagerTest : DarklyXCTestCase
@property (nonatomic, strong) id mockLDClient;
@property (nonatomic, strong) id mockLDClientManager;
@end

@implementation LDPollingManagerTest

- (void)setUp {
    [super setUp];
    
    id mockLDClient = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([mockLDClient sharedInstance])).andReturn(mockLDClient);
    self.mockLDClient = mockLDClient;

    id mockLDClientManager = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([mockLDClientManager sharedInstance])).andReturn(mockLDClientManager);
    self.mockLDClientManager = mockLDClientManager;
 }

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [self.mockLDClient stopMocking];
    [self.mockLDClientManager stopMocking];
    [super tearDown];
}

- (void)testEventPollingStates {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(YES);

    // create the expectation with a nice descriptive message
    LDPollingManager *dnu =  [LDPollingManager sharedInstance];
    dnu.eventPollingIntervalMillis = 5000; // for the purposes of the unit tests set it to 5 secs.
    [dnu startEventPolling];
    
    NSInteger expectedValue = POLL_RUNNING;
    NSInteger actualValue = [dnu eventPollingState];
    
    XCTAssertTrue(actualValue == expectedValue);
    
    [dnu pauseEventPolling];
    
    expectedValue = POLL_PAUSED;
    actualValue = [dnu eventPollingState];
    
    XCTAssertTrue(actualValue == expectedValue);
    
    [dnu stopEventPolling];
    
    expectedValue = POLL_STOPPED;
    actualValue = [dnu eventPollingState];
    
    XCTAssertTrue(actualValue == expectedValue);
}

- (void)testPollingInterval {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(YES);
    LDPollingManager *pollingManager =  [LDPollingManager sharedInstance];

    [pollingManager startConfigPolling];
    XCTAssertEqual(pollingManager.configPollingIntervalMillis, kDefaultPollingInterval*kMillisInSecs);
    XCTAssertEqual([pollingManager configPollingState], POLL_RUNNING);
    [pollingManager stopConfigPolling];

    [pollingManager startEventPolling];
    XCTAssertEqual(pollingManager.eventPollingIntervalMillis, kDefaultFlushInterval*kMillisInSecs);
    XCTAssertEqual([pollingManager eventPollingState], POLL_RUNNING);
    [pollingManager stopEventPolling];

    config.pollingInterval = [NSNumber numberWithInt:kMinimumPollingInterval - 1];
    [pollingManager startConfigPolling];
    XCTAssertEqual(pollingManager.configPollingIntervalMillis, kMinimumPollingInterval*kMillisInSecs);
    [pollingManager stopConfigPolling];

    config.pollingInterval = [NSNumber numberWithInt:kMinimumPollingInterval + 1];
    [pollingManager startConfigPolling];
    XCTAssertEqual(pollingManager.configPollingIntervalMillis, [config.pollingInterval intValue]*kMillisInSecs);
    [pollingManager stopConfigPolling];

    config.flushInterval = [NSNumber numberWithInt:50];
    [pollingManager startEventPolling];
    XCTAssertEqual(pollingManager.eventPollingIntervalMillis, [config.flushInterval intValue]*kMillisInSecs);
    [pollingManager stopEventPolling];
}

- (void)testConfigPollingOnline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(YES);

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopConfigPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);

    [pollingManager startConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_RUNNING);

    [pollingManager stopConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);
}

- (void)testConfigPollingOffline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(NO);

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopConfigPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);

    [pollingManager startConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);
}

- (void)testResumeConfigPollingOnline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(YES);

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopConfigPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);

    [pollingManager startConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_RUNNING);

    [pollingManager suspendConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_SUSPENDED);

    [pollingManager resumeConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_RUNNING);

    [pollingManager stopConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);
}

- (void)testResumeConfigPollingOffline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    [[[self.mockLDClientManager expect] andReturnValue:OCMOCK_VALUE(YES)] isOnline];

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopConfigPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);

    [pollingManager startConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_RUNNING);

    [pollingManager suspendConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_SUSPENDED);

    [[[self.mockLDClientManager expect] andReturnValue:OCMOCK_VALUE(NO)] isOnline];
    XCTAssertTrue([LDClientManager sharedInstance].isOnline == NO);

    [pollingManager resumeConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_SUSPENDED);

    [pollingManager stopConfigPolling];
    XCTAssertTrue(pollingManager.configPollingState == POLL_STOPPED);
}

- (void)testEventPollingOnline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(YES);

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopEventPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);

    [pollingManager startEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_RUNNING);

    [pollingManager stopEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);
}

- (void)testEventPollingOffline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(NO);

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopEventPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);

    [pollingManager startEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);
}

- (void)testResumeEventPollingOnline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    OCMStub([self.mockLDClientManager isOnline]).andReturn(YES);

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopEventPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);

    [pollingManager startEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_RUNNING);

    [pollingManager suspendEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_SUSPENDED);

    [pollingManager resumeEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_RUNNING);

    [pollingManager stopEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);
}

- (void)testResumeEventPollingOffline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.mockLDClient ldConfig]).andReturn(config);

    [[[self.mockLDClientManager expect] andReturnValue:OCMOCK_VALUE(YES)] isOnline];

    LDPollingManager *pollingManager = [LDPollingManager sharedInstance];
    [pollingManager stopEventPolling]; //Do not assume anything about polling manager state
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);

    [pollingManager startEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_RUNNING);

    [pollingManager suspendEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_SUSPENDED);

    [[[self.mockLDClientManager expect] andReturnValue:OCMOCK_VALUE(NO)] isOnline];
    XCTAssertTrue([LDClientManager sharedInstance].isOnline == NO);

    [pollingManager resumeEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_SUSPENDED);

    [pollingManager stopEventPolling];
    XCTAssertTrue(pollingManager.eventPollingState == POLL_STOPPED);
}

@end

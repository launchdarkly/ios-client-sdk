//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDPollingManager.h"
#import "LDDataManager.h"
#import "LDRequestManager.h"
#import "LDConfig.h"
#import "LDClient.h"
#import <OCMock.h>

@interface LDPollingManagerTest : DarklyXCTestCase
@property (nonatomic) id requestManagerMock;
@end

@implementation LDPollingManagerTest
@synthesize dataManagerMock;
@synthesize requestManagerMock;

- (void)setUp {
    [super setUp];
    
    LDRequestManager *requestManager = [LDRequestManager sharedInstance];
    requestManagerMock = OCMPartialMock(requestManager);
    OCMStub([requestManagerMock performFeatureFlagRequest:[OCMArg isKindOfClass:[NSString class]]]);

    id requestManagerClassMock = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([requestManagerClassMock sharedInstance])).andReturn(requestManagerClassMock);
 }

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [dataManagerMock stopMocking];
    [requestManagerMock stopMocking];
    [super tearDown];
}

- (void)testEventPollingStates {
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
    NSString *testMobileKey = @"testMobileKey";
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    LDClient *client = [LDClient sharedInstance];
    LDPollingManager *pollingManager =  [LDPollingManager sharedInstance];
    
    [client start:config userBuilder:nil];
    XCTAssertEqual(pollingManager.eventPollingIntervalMillis, kDefaultFlushInterval*kMillisInSecs);
    XCTAssertEqual([pollingManager configPollingState], POLL_STOPPED);
    [client stopClient];

    config.streaming = NO;
    [client start:config userBuilder:nil];
    XCTAssertEqual(pollingManager.eventPollingIntervalMillis, kDefaultPollingInterval*kMillisInSecs);
    XCTAssertEqual(pollingManager.configPollingIntervalMillis, kDefaultPollingInterval*kMillisInSecs);
    XCTAssertEqual([pollingManager configPollingState], POLL_RUNNING);
    [client stopClient];

    config.pollingInterval = [NSNumber numberWithInt:50];
    [client start:config userBuilder:nil];
    XCTAssertEqual(pollingManager.eventPollingIntervalMillis, kMinimumPollingInterval*kMillisInSecs);
    XCTAssertEqual(pollingManager.configPollingIntervalMillis, kMinimumPollingInterval*kMillisInSecs);
    [client stopClient];

    config.flushInterval = [NSNumber numberWithInt:50];
    [client start:config userBuilder:nil];
    XCTAssertEqual(pollingManager.eventPollingIntervalMillis, 50*kMillisInSecs);
    XCTAssertEqual(pollingManager.configPollingIntervalMillis, kMinimumPollingInterval*kMillisInSecs);
    [client stopClient];
}

@end

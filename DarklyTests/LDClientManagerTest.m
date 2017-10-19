//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDClientManager.h"
#import "LDUserBuilder.h"
#import "LDClient.h"
#import "OCMock.h"
#import "LDRequestManager.h"
#import "LDDataManager.h"
#import "LDPollingManager.h"
#import "LDEventModel.h"
#import "LDClientManager+EventSource.h"
#import "LDEvent+Testable.h"
#import "LDFlagConfigModel+Testable.h"

NSString *const mockMobileKey = @"mockMobileKey";
NSString *const kFeaturesJsonDictionary = @"featuresJsonDictionary";
NSString *const kBoolFlagKey = @"isABawler";

@interface LDClientManagerTest : DarklyXCTestCase
@property (nonatomic) id requestManagerMock;
@property (nonatomic) id ldClientMock;
@property (nonatomic) id dataManagerMock;
@property (nonatomic) id pollingManagerMock;
@property (nonatomic) id eventSourceMock;
@end

@implementation LDClientManagerTest
@synthesize requestManagerMock;
@synthesize ldClientMock;
@synthesize dataManagerMock;
@synthesize pollingManagerMock;
@synthesize eventSourceMock;

- (void)setUp {
    [super setUp];
    
    LDUserModel *user = [[LDUserModel alloc] init];
    user.key = [[NSUUID UUID] UUIDString];
    user.email = @"jeff@test.com";

    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];

    ldClientMock = [self mockClientWithUser:user];
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    [[[ldClientMock expect] andReturn: config] ldConfig];
    [[[ldClientMock expect] andReturn: user] ldUser];

    requestManagerMock = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([requestManagerMock sharedInstance])).andReturn(requestManagerMock);
    
    dataManagerMock = OCMClassMock([LDDataManager class]);
    OCMStub(ClassMethod([dataManagerMock sharedManager])).andReturn(dataManagerMock);
    
    pollingManagerMock = OCMClassMock([LDPollingManager class]);
    OCMStub(ClassMethod([pollingManagerMock sharedInstance])).andReturn(pollingManagerMock);

    eventSourceMock = OCMClassMock([LDEventSource class]);
    OCMStub(ClassMethod([eventSourceMock eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any]])).andReturn(eventSourceMock);
}

- (void)tearDown {
    [LDClientManager sharedInstance].online = NO;
    [ldClientMock stopMocking];
    [requestManagerMock stopMocking];
    [dataManagerMock stopMocking];
    [pollingManagerMock stopMocking];
    [eventSourceMock stopMocking];
    ldClientMock = nil;
    requestManagerMock = nil;
    dataManagerMock = nil;
    pollingManagerMock = nil;
    eventSourceMock = nil;
    [super tearDown];
}

- (void)testEventSourceCreatedOnStartPollingWhileOnline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    XCTAssertNotNil(clientManager.eventSource);
}

- (void)testEventSourceNotCreatedOnStartPollingWhileOffline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = NO;
    [clientManager startPolling];
    XCTAssertNil(clientManager.eventSource);
}

- (void)testEventSourceRemainsConstantAcrossStartPollingCalls {
    int numTries = 5;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    LDEventSource *eventSource = clientManager.eventSource;
    XCTAssertNotNil(eventSource);

    for (int i = 0; i < numTries; i++) {
        [clientManager startPolling];
        XCTAssert(eventSource == clientManager.eventSource);
    }
}

- (void)testEventSourceRemovedOnStopPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    XCTAssertNotNil(clientManager.eventSource);

    [clientManager stopPolling];
    XCTAssertNil(clientManager.eventSource);
}

- (void)testEventSourceCreatedOnWillEnterForeground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    XCTAssertNotNil(clientManager.eventSource);

    [clientManager willEnterBackground];
    XCTAssertNil(clientManager.eventSource);
    [clientManager willEnterForeground];
    XCTAssertNotNil(clientManager.eventSource);
}

- (void)testEventSourceRemainsConstantAcrossWillEnterForegroundCalls {
    int numTries = 5;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    XCTAssertNotNil(clientManager.eventSource);

    LDEventSource *eventSource = [[LDClientManager sharedInstance] eventSource];
    for (int i = 0; i < numTries; i++) {
        [clientManager willEnterForeground];
        XCTAssert(eventSource == clientManager.eventSource);
    }
}

- (void)testSyncWithServerForConfigWhenUserExistsAndOnline {
    [[requestManagerMock expect] performFeatureFlagRequest:[ldClientMock ldUser]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];
    
    [clientManager syncWithServerForConfig];

    [requestManagerMock verify];
}

- (void)testSyncWithServerForConfigWhenUserDoesNotExist {
    [self mockClientWithUser:nil];
    XCTAssertNil([LDClient sharedInstance].ldUser);
    
    [[requestManagerMock reject] performFeatureFlagRequest:[OCMArg any]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];

    [clientManager syncWithServerForConfig];
}

- (void)testSyncWithServerForConfigWhenOffline {
    [[requestManagerMock reject] performFeatureFlagRequest:[OCMArg any]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:NO];

    [clientManager syncWithServerForConfig];
}

- (void)testSyncWithServerForEventsWhenEventsExist {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];

    [dataManagerMock allEventsJsonArray:^(NSArray *array) {
        OCMStub(array).andReturn(testData);
        
        [clientManager syncWithServerForEvents];
        
        OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    }];
}

- (void)testDoNotSyncWithServerForEventsWhenEventsDoNotExist {
    NSData *testData = nil;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];

    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    [clientManager syncWithServerForEvents];
    
    [requestManagerMock verify];
}

- (void)testSyncWithServerForEventsNotProcessedWhenOffline {
    NSData *testData = [[NSData alloc] init];
    
    [dataManagerMock allEventsJsonArray:^(NSArray *array) {
        OCMStub(array).andReturn(testData);
        
        [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
        
        LDClientManager *clientManager = [LDClientManager sharedInstance];
        [clientManager setOnline:NO];
        [clientManager syncWithServerForEvents];
        
        [requestManagerMock verify];
    }];
}

- (void)testStartPollingOnline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    
    OCMVerify([pollingManagerMock startEventPolling]);
    OCMVerify([eventSourceMock onMessage:[OCMArg isNotNil]]);
}

- (void)testStartPollingOffline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = NO;
    [clientManager startPolling];

    OCMReject([pollingManagerMock startEventPolling]);
    XCTAssertNil(clientManager.eventSource);
}

- (void)testStopPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager stopPolling];
    
    OCMVerify([pollingManagerMock stopEventPolling]);
    XCTAssertNil([clientManager eventSource]);
}

- (void)testWillEnterBackground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager willEnterBackground];
    
    OCMVerify([pollingManagerMock suspendEventPolling]);
}

- (void)testWillEnterForeground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager willEnterForeground];
    
    OCMVerify([pollingManagerMock resumeEventPolling]);
}

- (void)testProcessedEventsSuccessWithProcessedEvents {
    LDEventModel *event = [[LDEventModel alloc] initFeatureEventWithKey:@"blah" keyValue:[NSNumber numberWithBool:NO] defaultKeyValue:[NSNumber numberWithBool:NO] userValue:[[LDClient sharedInstance] ldUser]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:YES jsonEventArray:@[[event dictionaryValue]]];
    
    OCMVerify([dataManagerMock deleteProcessedEvents:[OCMArg any]]);
}

- (void)testProcessedEventsSuccessWithoutProcessedEvents {
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:YES jsonEventArray:@[]];
    
    [[dataManagerMock reject] deleteProcessedEvents:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedEventsFailure {
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:NO jsonEventArray:nil];
    
    [[dataManagerMock reject] deleteProcessedEvents:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedConfigSuccessWithUserConfigChanged {
    id mockUserUpdatedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserUpdatedObserver name:kLDUserUpdatedNotification object:nil];
    [[mockUserUpdatedObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    id mockUserNoChangeObserver = OCMObserverMock();    //expect this NOT to be posted
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserNoChangeObserver name:kLDUserNoChangeNotification object:nil];

    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"feature_flags"];

    LDUserModel *user = [ldClientMock ldUser];
    user.config = flagConfig;
    [[[ldClientMock expect] andReturn:user] ldUser];

    NSMutableDictionary *updatedFlags = [NSMutableDictionary dictionaryWithDictionary:flagConfig.featuresJsonDictionary];
    XCTAssertNotNil(updatedFlags[kBoolFlagKey]);
    updatedFlags[kBoolFlagKey] = @(![updatedFlags[kBoolFlagKey] boolValue]);

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[updatedFlags copy]];
    
    OCMVerify([dataManagerMock saveUser:[OCMArg any]]);
    OCMVerifyAll(mockUserUpdatedObserver);
    OCMVerifyAll(mockUserNoChangeObserver);
}

- (void)testProcessedConfigSuccessWithUserConfigUnchanged {
    id mockUserUpdatedObserver = OCMObserverMock(); //expect this NOT to be posted
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserUpdatedObserver name:kLDUserUpdatedNotification object:nil];

    id mockUserNoChangeObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserNoChangeObserver name:kLDUserNoChangeNotification object:nil];
    [[mockUserNoChangeObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"feature_flags"];

    LDUserModel *user = [ldClientMock ldUser];
    user.config = flagConfig;
    [[[ldClientMock expect] andReturn:user] ldUser];

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[flagConfig.featuresJsonDictionary copy]];

    OCMVerifyAll(dataManagerMock);
    OCMVerifyAll(mockUserUpdatedObserver);
    OCMVerifyAll(mockUserNoChangeObserver);
}

- (void)testProcessedConfigSuccessWithoutUserConfig {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:YES jsonConfigDictionary:nil];
    
    [[dataManagerMock reject] saveUser:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedConfigFailure {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:NO jsonConfigDictionary:nil];
    
    [[dataManagerMock reject] saveUser:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedConfigSuccessWithUserSameUserConfig {
    LDFlagConfigModel *startingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigA"];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.config = startingConfig;
    
    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:startingConfig.featuresJsonDictionary];
    XCTAssertTrue(clientUser.config == startingConfig);     //Should be the same object, unchanged
}

- (void)testProcessedConfigSuccessWithUserDifferentUserConfig {
    LDFlagConfigModel *startingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigA"];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.config = startingConfig;
    
    LDFlagConfigModel *endingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigB"];
    XCTAssertNotNil(endingConfig);

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:endingConfig.featuresJsonDictionary];
    XCTAssertFalse(clientUser.config == startingConfig);     //Should not be the same object
    XCTAssertTrue([clientUser.config isEqualToConfig:endingConfig]);
}

- (void)testSetOnlineYes {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    OCMVerify([pollingManagerMock startEventPolling]);
    OCMVerify([eventSourceMock onMessage:[OCMArg any]]);
}

- (void)testSetOnlineNo {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    clientManager.online = NO;

    OCMVerify([pollingManagerMock stopEventPolling]);
    XCTAssertNil([clientManager eventSource]);
}

- (void)testFlushEventsWhenOnline {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    [dataManagerMock allEventsJsonArray:^(NSArray *array) {
        OCMStub(array).andReturn(testData);

        [clientManager flushEvents];

        OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    }];
}

- (void)testFlushEventsWhenOffline {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = NO;

    [dataManagerMock allEventsJsonArray:^(NSArray *array) {
        OCMStub(array).andReturn(testData);

        [clientManager flushEvents];

        OCMReject([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    }];
}

- (void)testClientUnauthorizedPosted {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    [[clientUnauthorizedObserver expect] notificationWithName: kLDClientUnauthorizedNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler errorHandler;
    OCMStub([eventSourceMock onError:[OCMArg checkWithBlock:^BOOL(id obj) {
        errorHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(errorHandler);
    if (!errorHandler) { return; }
    errorHandler([LDEvent stubUnauthorizedEvent]);

    [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
    [clientUnauthorizedObserver verify];

    clientManager.online = NO;  //Although LDClientManager.online = NO is in tearDown, setting it here allows following tests to not fail on errorHandler != nil
}

- (void)testClientUnauthorizedNotPosted {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    __block LDEventSourceEventHandler errorHandler;
    OCMStub([eventSourceMock onError:[OCMArg checkWithBlock:^BOOL(id obj) {
        errorHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(errorHandler);
    if (!errorHandler) { return; }
    errorHandler([LDEvent stubErrorEvent]);

    [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
    [clientUnauthorizedObserver verify];

    clientManager.online = NO;  //Although LDClientManager.online = NO is in tearDown, setting it here allows following tests to not fail on errorHandler != nil
}

#pragma mark - Helpers

- (id)mockClientWithUser:(LDUserModel*)user {
    id mockClient = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([mockClient sharedInstance])).andReturn(mockClient);
    OCMStub([mockClient ldUser]).andReturn(user);
    XCTAssertEqual([LDClient sharedInstance].ldUser, user);
    
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"testMobileKey"];
    config.flushInterval = [NSNumber numberWithInt:30];
    OCMStub([mockClient ldConfig]).andReturn(config);
    XCTAssertEqual([LDClient sharedInstance].ldConfig, config);
    
    return mockClient;
}

@end

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
#import "LDEvent+EventTypes.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDUserModel+Stub.h"
#import "NSJSONSerialization+Testable.h"
#import "LDUserModel+Equatable.h"

extern NSString * _Nonnull const kLDFlagConfigJsonDictionaryKeyValue;
extern NSString * _Nonnull const kLDFlagConfigJsonDictionaryKeyVersion;
extern NSString * _Nonnull const kLDClientManagerStreamMethod;


NSString *const mockMobileKey = @"mockMobileKey";
NSString *const kFeaturesJsonDictionary = @"featuresJsonDictionary";
NSString *const kBoolFlagKey = @"isABawler";

@interface LDClientManagerTest : DarklyXCTestCase
@property (nonatomic) id requestManagerMock;
@property (nonatomic) id ldClientMock;
@property (nonatomic) id dataManagerMock;
@property (nonatomic) id pollingManagerMock;
@property (nonatomic) id eventSourceMock;
@property (nonatomic, strong) void (^cleanup)(void);
@end

@implementation LDClientManagerTest
@synthesize requestManagerMock;
@synthesize ldClientMock;
@synthesize dataManagerMock;
@synthesize pollingManagerMock;
@synthesize eventSourceMock;

- (void)setUp {
    [super setUp];
    
    LDUserModel *user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];

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
    OCMStub(ClassMethod([eventSourceMock eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]])).andReturn(eventSourceMock);
}

- (void)tearDown {
    if (self.cleanup) { self.cleanup(); }
    [LDClientManager sharedInstance].online = NO;
    [ldClientMock stopMocking];
    [requestManagerMock stopMocking];
    [dataManagerMock stopMocking];
    [pollingManagerMock stopMocking];
    [eventSourceMock stopMocking];
    self.cleanup = nil;
    ldClientMock = nil;
    requestManagerMock = nil;
    dataManagerMock = nil;
    pollingManagerMock = nil;
    eventSourceMock = nil;
    [super tearDown];
}

- (void)testEventSourceConfiguredToConnectUsingGetMethod {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    LDUserModel *user = [LDClient sharedInstance].ldUser;
    NSString *encodedUser = [LDUtil base64UrlEncodeString:[[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString]];

    __block NSURL *streamUrl;
    __block NSString *streamConnectMethod;
    __block NSData *streamConnectData;
    OCMVerify([eventSourceMock eventSourceWithURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSURL class]]) { return NO; }
        streamUrl = obj;
        return YES;
    }] httpHeaders:[OCMArg any] connectMethod:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (obj && ![obj isKindOfClass:[NSString class]]) { return NO; }
        streamConnectMethod = obj;
        return YES;
    }] connectBody:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (obj && ![obj isKindOfClass:[NSData class]]) { return NO; }
        streamConnectData = obj;
        return YES;
    }]]);
    XCTAssertTrue([[streamUrl pathComponents] containsObject:kLDClientManagerStreamMethod]);
    XCTAssertFalse([[streamUrl pathComponents] containsObject:@"mping"]);
    XCTAssertTrue([[streamUrl lastPathComponent] isEqualToString:encodedUser]);
    XCTAssertTrue(streamConnectMethod == nil || [streamConnectMethod isEqualToString:@"GET"]);
    XCTAssertNil(streamConnectData);
}

- (void)testEventSourceConfiguredToConnectUsingReportMethod {
    LDConfig *config = [LDClient sharedInstance].ldConfig;
    config.useReport = YES;
    LDUserModel *user = [LDClient sharedInstance].ldUser;

    [ldClientMock stopMocking];
    ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    OCMStub([ldClientMock ldUser]).andReturn(user);
    OCMStub([ldClientMock ldConfig]).andReturn(config);

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    NSData *encodedUserData = [[[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString] dataUsingEncoding:NSUTF8StringEncoding];

    __block NSURL *streamUrl;
    __block NSString *streamConnectMethod;
    __block NSData *streamConnectData;
    OCMVerify([eventSourceMock eventSourceWithURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSURL class]]) { return NO; }
        streamUrl = obj;
        return YES;
    }] httpHeaders:[OCMArg any] connectMethod:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (obj && ![obj isKindOfClass:[NSString class]]) { return NO; }
        streamConnectMethod = obj;
        return YES;
    }] connectBody:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (obj && ![obj isKindOfClass:[NSData class]]) { return NO; }
        streamConnectData = obj;
        return YES;
    }]]);
    XCTAssertTrue([[streamUrl lastPathComponent] isEqualToString:kLDClientManagerStreamMethod]);
    XCTAssertFalse([[streamUrl pathComponents] containsObject:@"mping"]);
    XCTAssertTrue([streamConnectMethod isEqualToString:kHTTPMethodReport]);
    XCTAssertTrue([streamConnectData isEqualToData:encodedUserData]);
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
    ldClientMock = [self mockClientWithUser:nil];

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

    [dataManagerMock allEventDictionaries:^(NSArray *array) {
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
    
    [dataManagerMock allEventDictionaries:^(NSArray *array) {
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
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"testMobileKey"];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:YES jsonEventArray:@[[event dictionaryValueUsingConfig:config]]];
    
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

    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];

    LDUserModel *user = [ldClientMock ldUser];
    user.config = flagConfig;
    [[[ldClientMock expect] andReturn:user] ldUser];

    NSMutableDictionary *updatedFlags = [NSMutableDictionary dictionaryWithDictionary:[flagConfig dictionaryValue]];
    NSMutableDictionary *updatedBoolFlag = [NSMutableDictionary dictionaryWithDictionary:updatedFlags[kBoolFlagKey]];
    updatedBoolFlag[kLDFlagConfigJsonDictionaryKeyValue] = @(![updatedBoolFlag[kLDFlagConfigJsonDictionaryKeyValue] boolValue]);
    updatedBoolFlag[kLDFlagConfigJsonDictionaryKeyVersion] = @([updatedBoolFlag[kLDFlagConfigJsonDictionaryKeyVersion] integerValue] + 1);
    updatedFlags[kBoolFlagKey] = updatedBoolFlag;

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[updatedFlags copy]];
    
    OCMVerify([dataManagerMock saveUser:[OCMArg any]]);
    OCMVerifyAll(mockUserUpdatedObserver);
    OCMVerifyAll(mockUserNoChangeObserver);

    [[NSNotificationCenter defaultCenter] removeObserver:mockUserUpdatedObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:mockUserNoChangeObserver];
}

- (void)testProcessedConfigSuccessWithUserConfigUnchanged {
    id mockUserUpdatedObserver = OCMObserverMock(); //expect this NOT to be posted
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserUpdatedObserver name:kLDUserUpdatedNotification object:nil];

    id mockUserNoChangeObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserNoChangeObserver name:kLDUserNoChangeNotification object:nil];
    [[mockUserNoChangeObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];

    LDUserModel *user = [ldClientMock ldUser];
    user.config = flagConfig;
    [[[ldClientMock expect] andReturn:user] ldUser];

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[flagConfig dictionaryValue]];

    OCMVerifyAll(dataManagerMock);
    OCMVerifyAll(mockUserUpdatedObserver);
    OCMVerifyAll(mockUserNoChangeObserver);

    [[NSNotificationCenter defaultCenter] removeObserver:mockUserUpdatedObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:mockUserNoChangeObserver];
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
    
    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[startingConfig dictionaryValue]];
    XCTAssertTrue(clientUser.config == startingConfig);     //Should be the same object, unchanged
}

- (void)testProcessedConfigSuccessWithUserDifferentUserConfig {
    LDFlagConfigModel *startingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigA"];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.config = startingConfig;
    
    LDFlagConfigModel *endingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigB"];
    XCTAssertNotNil(endingConfig);

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[endingConfig dictionaryValue]];
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

    [dataManagerMock allEventDictionaries:^(NSArray *array) {
        OCMStub(array).andReturn(testData);

        [clientManager flushEvents];

        OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    }];
}

- (void)testFlushEventsWhenOffline {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = NO;

    [dataManagerMock allEventDictionaries:^(NSArray *array) {
        OCMStub(array).andReturn(testData);

        [clientManager flushEvents];

        OCMReject([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    }];
}

- (void)testClientUnauthorizedPosted {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    [[clientUnauthorizedObserver expect] notificationWithName: kLDClientUnauthorizedNotification object:[OCMArg any]];

    id serverUnavailableObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:serverUnavailableObserver name:kLDServerConnectionUnavailableNotification object:nil];
    [[serverUnavailableObserver expect] notificationWithName: kLDServerConnectionUnavailableNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler errorHandler;
    OCMStub([eventSourceMock onError:[OCMArg checkWithBlock:^BOOL(id obj) {
        errorHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:serverUnavailableObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(errorHandler);
    if (!errorHandler) { return; }
    errorHandler([LDEvent stubUnauthorizedEvent]);

    [clientUnauthorizedObserver verify];
    [serverUnavailableObserver verify];
}

- (void)testClientUnauthorizedNotPosted {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    id serverUnavailableObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:serverUnavailableObserver name:kLDServerConnectionUnavailableNotification object:nil];
    [[serverUnavailableObserver expect] notificationWithName: kLDServerConnectionUnavailableNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler errorHandler;
    OCMStub([eventSourceMock onError:[OCMArg checkWithBlock:^BOOL(id obj) {
        errorHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:serverUnavailableObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(errorHandler);
    if (!errorHandler) { return; }
    errorHandler([LDEvent stubErrorEvent]);

    [clientUnauthorizedObserver verify];
    [serverUnavailableObserver verify];
}

- (void)testSSEPingEvent {
    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }
    messageHandler([LDEvent stubPingEvent]);

    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        LDUserModel *userFromRequest = (LDUserModel*)obj;
        return [user isEqual:userFromRequest];
    }]]);
}

- (void)testSSEPutEventSuccess {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }
    
    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-withVersions"];

    messageHandler(put);

    XCTAssertTrue([user.config isEqualToConfig: targetFlagConfig]);
    __block LDUserModel *savedUser;
    OCMVerify([dataManagerMock saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        savedUser = obj;
        return YES;
    }]]);
    XCTAssertTrue([savedUser.config isEqualToConfig:targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
}

- (void)testSSEPutResultedInNoChange {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    __block NSDictionary *putDictionary;
    [[flagConfigMock expect] addOrReplaceFromDictionary:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        putDictionary = obj;
        return YES;
    }]];
    OCMStub([flagConfigMock isEqualToConfig:[OCMArg any]]).andReturn(YES);
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    //NOTE: Because the flag config mock will return YES on a config comparison, the put here doesn't matter
    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-withVersions"];

    messageHandler(put);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPutEventFailedNilData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.config;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-withVersions"];
    put.data = nil;

    messageHandler(put);

    XCTAssertTrue([user.config isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPutEventFailedEmptyData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.config;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-withVersions"];
    put.data = @"";

    messageHandler(put);

    XCTAssertTrue([user.config isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPutEventFailedInvalidData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.config;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-withVersions"];
    put.data = @"{\"someInvalidData\":}";

    messageHandler(put);

    XCTAssertTrue([user.config isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEUnrecognizedEvent {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.config;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:@"someUnrecognizedEvent" fromJsonFileNamed:@"featureFlags-withVersions"];

    messageHandler(put);

    XCTAssertTrue([user.config isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPatchEventSuccess {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    OCMStub([flagConfigMock hasFeaturesEqualToDictionary:[OCMArg any]]).andReturn(NO);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldClientManagerTestPatchIsANumber"];
    NSDictionary *targetPatchDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"ldClientManagerTestPatchIsANumber"];

    messageHandler(patch);

    __block NSDictionary *patchDictionary;
    OCMVerify([flagConfigMock addOrReplaceFromDictionary:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        patchDictionary = obj;
        return YES;
    }]]);
    XCTAssertTrue([patchDictionary isEqualToDictionary:targetPatchDictionary]);
    __block LDUserModel *savedUser;
    OCMVerify([dataManagerMock saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        savedUser = obj;
        return YES;
    }]]);
    XCTAssertTrue([savedUser isEqual:user]);
    OCMVerifyAll(notificationObserver);
}

- (void)testSSEPatchResultedInNoChange {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    __block NSDictionary *patchDictionary;
    [[flagConfigMock expect] addOrReplaceFromDictionary:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        patchDictionary = obj;
        return YES;
    }]];
    OCMStub([flagConfigMock hasFeaturesEqualToDictionary:[OCMArg any]]).andReturn(YES);
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    //NOTE: Because the flag config mock will return YES on a dictionary comparison, the patch here doesn't matter
    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldClientManagerTestPatchIsANumber"];

    messageHandler(patch);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPatchFailedNilData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] addOrReplaceFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldClientManagerTestPatchIsANumber"];
    patch.data = nil;

    messageHandler(patch);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPatchFailedEmptyData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] addOrReplaceFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldClientManagerTestPatchIsANumber"];
    patch.data = @"";

    messageHandler(patch);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEPatchFailedInvalidData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] addOrReplaceFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldClientManagerTestPatchIsANumber"];
    patch.data = @"{\"someInvalidData\":}";

    messageHandler(patch);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEDeleteEventSuccess {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    OCMStub([flagConfigMock hasFeaturesEqualToDictionary:[OCMArg any]]).andReturn(NO);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    self.cleanup = ^{
        [flagConfigMock stopMocking];
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldClientManagerTestDeleteIsANumber"];
    NSDictionary *targetDeleteDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"ldClientManagerTestDeleteIsANumber"];

    messageHandler(delete);

    __block NSDictionary *deleteDictionary;
    OCMVerify([flagConfigMock deleteFromDictionary:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        deleteDictionary = obj;
        return YES;
    }]]);
    XCTAssertTrue([deleteDictionary isEqualToDictionary:targetDeleteDictionary]);
    __block LDUserModel *savedUser;
    OCMVerify([dataManagerMock saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        savedUser = obj;
        return YES;
    }]]);
    XCTAssertNotNil(savedUser);
    XCTAssertTrue([savedUser isEqual:user]);
    OCMVerifyAll(notificationObserver);
}

- (void)testSSEDeleteResultedInNoChange {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    __block NSDictionary *deleteDictionary;
    [[flagConfigMock expect] deleteFromDictionary:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        deleteDictionary = obj;
        return YES;
    }]];
    OCMStub([flagConfigMock hasFeaturesEqualToDictionary:[OCMArg any]]).andReturn(YES);
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    //NOTE: Because the flag config mock will return YES on a dictionary comparison, the delete here doesn't matter
    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldClientManagerTestDeleteIsANumber"];

    messageHandler(delete);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEDeleteFailedNilData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] deleteFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldClientManagerTestDeleteIsANumber"];
    delete.data = nil;

    messageHandler(delete);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEDeleteFailedEmptyData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] deleteFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldClientManagerTestDeleteIsANumber"];
    delete.data = @"";

    messageHandler(delete);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
}

- (void)testSSEDeleteFailedInvalidData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] deleteFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.config = flagConfigMock;

    [[dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldClientManagerTestDeleteIsANumber"];
    delete.data = @"{\"someInvalidData\":}";

    messageHandler(delete);

    OCMVerifyAll(notificationObserver);
    OCMVerify(dataManagerMock);
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

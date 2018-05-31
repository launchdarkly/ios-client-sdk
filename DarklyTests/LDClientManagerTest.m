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
#import "LDEventModel+Testable.h"
#import "LDClientManager+EventSource.h"
#import "LDEvent+Testable.h"
#import "LDEvent+EventTypes.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"
#import "LDUserModel+Testable.h"
#import "NSJSONSerialization+Testable.h"
#import "LDFlagConfigTracker+Testable.h"
#import "NSDate+ReferencedDate.h"
#import "NSDate+Testable.h"
#import "NSDateFormatter+JsonHeader+Testable.h"
#import "NSDate+ReferencedDate.h"

extern NSString * _Nonnull const kLDFlagConfigValueKeyValue;
extern NSString * _Nonnull const kLDFlagConfigValueKeyVersion;
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

- (void)setUp {
    [super setUp];
    
    LDUserModel *user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];

    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];

    self.ldClientMock = [self mockClientWithUser:user];
    OCMStub(ClassMethod([self.ldClientMock sharedInstance])).andReturn(self.ldClientMock);
    [[[self.ldClientMock expect] andReturn: config] ldConfig];
    [[[self.ldClientMock expect] andReturn: user] ldUser];

    self.requestManagerMock = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([self.requestManagerMock sharedInstance])).andReturn(self.requestManagerMock);
    
    self.dataManagerMock = OCMClassMock([LDDataManager class]);
    OCMStub(ClassMethod([self.dataManagerMock sharedManager])).andReturn(self.dataManagerMock);
    
    self.pollingManagerMock = OCMClassMock([LDPollingManager class]);
    OCMStub(ClassMethod([self.pollingManagerMock sharedInstance])).andReturn(self.pollingManagerMock);

    self.eventSourceMock = OCMClassMock([LDEventSource class]);
    OCMStub(ClassMethod([self.eventSourceMock eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]])).andReturn(self.eventSourceMock);
}

- (void)tearDown {
    if (self.cleanup) { self.cleanup(); }
    [LDClientManager sharedInstance].online = NO;
    [self.ldClientMock stopMocking];
    [self.requestManagerMock stopMocking];
    [self.dataManagerMock stopMocking];
    [self.pollingManagerMock stopMocking];
    [self.eventSourceMock stopMocking];
    self.cleanup = nil;
    self.ldClientMock = nil;
    self.requestManagerMock = nil;
    self.dataManagerMock = nil;
    self.pollingManagerMock = nil;
    self.eventSourceMock = nil;
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
    OCMVerify([self.eventSourceMock eventSourceWithURL:[OCMArg checkWithBlock:^BOOL(id obj) {
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

    [self.ldClientMock stopMocking];
    self.ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([self.ldClientMock sharedInstance])).andReturn(self.ldClientMock);
    OCMStub([self.ldClientMock ldUser]).andReturn(user);
    OCMStub([self.ldClientMock ldConfig]).andReturn(config);

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    NSData *encodedUserData = [[[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString] dataUsingEncoding:NSUTF8StringEncoding];

    __block NSURL *streamUrl;
    __block NSString *streamConnectMethod;
    __block NSData *streamConnectData;
    OCMVerify([self.eventSourceMock eventSourceWithURL:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    [[self.requestManagerMock expect] performFeatureFlagRequest:[self.ldClientMock ldUser]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];
    
    [clientManager syncWithServerForConfig];

    [self.requestManagerMock verify];
}

- (void)testSyncWithServerForConfigWhenUserDoesNotExist {
    self.ldClientMock = [self mockClientWithUser:nil];

    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];

    [clientManager syncWithServerForConfig];
}

- (void)testSyncWithServerForConfigWhenOffline {
    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:NO];

    [clientManager syncWithServerForConfig];
}

- (void)testSyncWithServerForEventsWhenEventsExist {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    NSArray<NSDictionary*> *eventDictionaries = [LDEventModel stubEventDictionariesForUser:[LDClient sharedInstance].ldUser config:config];
    OCMStub([self.dataManagerMock allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(eventDictionaries);
        return YES;
    }]]);
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];
    LDMillisecond startDateMillis = [[NSDate date] millisSince1970];

    [clientManager syncWithServerForEvents];

    OCMVerify([self.requestManagerMock performEventRequest:[OCMArg isEqual:eventDictionaries]]);
    XCTAssertNotNil([LDClient sharedInstance].ldUser.flagConfigTracker);
    XCTAssertTrue([LDClient sharedInstance].ldUser.flagConfigTracker.flagCounters.count == 0);
    XCTAssertTrue(Approximately([LDClient sharedInstance].ldUser.flagConfigTracker.startDateMillis, startDateMillis, 10));
}

- (void)testDoNotSyncWithServerForEventsWhenEventsDoNotExist {
    NSData *testData = nil;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOnline:YES];

    [[self.requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    [clientManager syncWithServerForEvents];
    
    [self.requestManagerMock verify];
}

- (void)testSyncWithServerForEventsNotProcessedWhenOffline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    NSArray<NSDictionary*> *eventDictionaries = [LDEventModel stubEventDictionariesForUser:[LDClient sharedInstance].ldUser config:config];
    OCMStub([self.dataManagerMock allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(eventDictionaries);
        return YES;
    }]]);
    [[self.requestManagerMock reject] performEventRequest:[OCMArg any]];
    [[self.dataManagerMock reject] allEventDictionaries:[OCMArg any]];

    [[LDClientManager sharedInstance] syncWithServerForEvents];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testStartPollingOnline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    [clientManager startPolling];
    
    OCMVerify([self.pollingManagerMock startEventPolling]);
    OCMVerify([self.eventSourceMock onMessage:[OCMArg isNotNil]]);
}

- (void)testStartPollingOffline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = NO;
    [clientManager startPolling];

    OCMReject([self.pollingManagerMock startEventPolling]);
    XCTAssertNil(clientManager.eventSource);
}

- (void)testStopPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager stopPolling];
    
    OCMVerify([self.pollingManagerMock stopEventPolling]);
    XCTAssertNil([clientManager eventSource]);
}

- (void)testUpdateUser_offline_streaming {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    config.streaming = YES;
    [[self.eventSourceMock reject] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    [[self.pollingManagerMock reject] startConfigPolling];

    [[LDClientManager sharedInstance] updateUser];

    [self.eventSourceMock verify];
    [self.pollingManagerMock verify];
}

- (void)testUpdateUser_offline_polling {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    config.streaming = NO;
    [[self.eventSourceMock reject] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    [[self.pollingManagerMock reject] startConfigPolling];

    [[LDClientManager sharedInstance] updateUser];

    [self.eventSourceMock verify];
    [self.pollingManagerMock verify];
}

- (void)testUpdateUser_online_streaming {
    LDConfig *config = [LDClient sharedInstance].ldConfig;
    config.streaming = YES;
    [[LDClientManager sharedInstance] setOnline:YES];
    //The eventSourceMock registered the eventSourceWithURL call from the setOnline call above. Replace it so it can measure the updateUser response
    [self.eventSourceMock stopMocking];
    self.eventSourceMock = OCMClassMock([LDEventSource class]);
    OCMStub(ClassMethod([self.eventSourceMock eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]])).andReturn(self.eventSourceMock);
    [[self.eventSourceMock expect] close];
    [[self.pollingManagerMock expect] stopConfigPolling];
    [[self.pollingManagerMock reject] startConfigPolling];

    [[LDClientManager sharedInstance] updateUser];

    //Calling verify on the mock isn't working correctly, but the macro syntax does
    OCMVerify([self.eventSourceMock eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]]);
    [self.pollingManagerMock verify];
}

- (void)testUpdateUser_online_polling {
    LDConfig *config = [LDClient sharedInstance].ldConfig;
    config.streaming = NO;
    [[LDClientManager sharedInstance] setOnline:YES];
    [[self.eventSourceMock reject] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    [[self.pollingManagerMock expect] stopConfigPolling];
    [[self.pollingManagerMock expect] startConfigPolling];

    [[LDClientManager sharedInstance] updateUser];

    [self.eventSourceMock verify];
    [self.pollingManagerMock verify];
}

- (void)testWillEnterBackground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager willEnterBackground];
    
    OCMVerify([self.pollingManagerMock suspendEventPolling]);
}

- (void)testWillEnterForeground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager willEnterForeground];
    
    OCMVerify([self.pollingManagerMock resumeEventPolling]);
}

- (void)testProcessedEventsSuccessWithProcessedEvents {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"testMobileKey"];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true"
                                                                                     flagKey:kLDFlagKeyIsABool
                                                                        eventTrackingContext:[LDEventTrackingContext stub]];
    LDEventModel *event = [LDEventModel featureEventWithFlagKey:kFeatureEventKeyStub
                                              reportedFlagValue:flagConfigValue.value
                                                flagConfigValue:flagConfigValue
                                               defaultFlagValue:@(NO)
                                                           user:[LDClient sharedInstance].ldUser
                                                     inlineUser:config.inlineUserInEvents];
    NSArray *events = @[[event dictionaryValueUsingConfig:config]];
    NSDate *headerDate = [NSDateFormatter eventDateHeaderStub];
    [[self.dataManagerMock expect] deleteProcessedEvents:events];
    [[self.dataManagerMock expect] setLastEventResponseDate:headerDate];

    [[LDClientManager sharedInstance] processedEvents:YES jsonEventArray:events responseDate:headerDate];
    
    [self.dataManagerMock verify];
}

- (void)testProcessedEventsSuccessWithoutProcessedEvents {
    NSDate *headerDate = [NSDateFormatter eventDateHeaderStub];
    [[self.dataManagerMock expect] deleteProcessedEvents:@[]];
    [[self.dataManagerMock expect] setLastEventResponseDate:headerDate];

    [[LDClientManager sharedInstance] processedEvents:YES jsonEventArray:@[] responseDate:headerDate];

    [self.dataManagerMock verify];
}

- (void)testProcessedEventsFailure {
    [[self.dataManagerMock reject] deleteProcessedEvents:[OCMArg any]];

    [[LDClientManager sharedInstance] processedEvents:NO jsonEventArray:nil responseDate:nil];
    
    [self.dataManagerMock verify];
}

- (void)testProcessedConfigSuccessWithUserConfigChanged {
    id mockUserUpdatedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserUpdatedObserver name:kLDUserUpdatedNotification object:nil];
    [[mockUserUpdatedObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    id mockUserNoChangeObserver = OCMObserverMock();    //expect this NOT to be posted
    [[NSNotificationCenter defaultCenter] addMockObserver:mockUserNoChangeObserver name:kLDUserNoChangeNotification object:nil];

    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];

    LDUserModel *user = [self.ldClientMock ldUser];
    user.flagConfig = flagConfig;
    [[[self.ldClientMock expect] andReturn:user] ldUser];

    NSMutableDictionary *updatedFlags = [NSMutableDictionary dictionaryWithDictionary:[flagConfig dictionaryValue]];
    NSMutableDictionary *updatedBoolFlag = [NSMutableDictionary dictionaryWithDictionary:updatedFlags[kBoolFlagKey]];
    updatedBoolFlag[kLDFlagConfigValueKeyValue] = @(![updatedBoolFlag[kLDFlagConfigValueKeyValue] boolValue]);
    updatedBoolFlag[kLDFlagConfigValueKeyVersion] = @([updatedBoolFlag[kLDFlagConfigValueKeyVersion] integerValue] + 1);
    updatedFlags[kBoolFlagKey] = updatedBoolFlag;

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[updatedFlags copy]];
    
    OCMVerify([self.dataManagerMock saveUser:[OCMArg any]]);
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

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext contextWithTrackEvents:NO debugEventsUntilDate:nil];
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags" eventTrackingContext:eventTrackingContext];

    LDUserModel *user = [self.ldClientMock ldUser];
    user.flagConfig = flagConfig;
    [[[self.ldClientMock expect] andReturn:user] ldUser];

    LDEventTrackingContext *updatedEventTrackingContext = [LDEventTrackingContext contextWithTrackEvents:YES debugEventsUntilDate:[NSDate dateWithTimeIntervalSinceNow:30.0]];
    LDFlagConfigModel *updatedFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags" eventTrackingContext:updatedEventTrackingContext];

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[updatedFlagConfig dictionaryValue]];

    for (NSString *flagKey in flagConfig.featuresJsonDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = flagConfig.featuresJsonDictionary[flagKey];
        XCTAssertEqualObjects(flagConfigValue.eventTrackingContext, updatedEventTrackingContext);
    }

    OCMVerifyAll(self.dataManagerMock);
    OCMVerifyAll(mockUserUpdatedObserver);
    OCMVerifyAll(mockUserNoChangeObserver);

    [[NSNotificationCenter defaultCenter] removeObserver:mockUserUpdatedObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:mockUserNoChangeObserver];
}

- (void)testProcessedConfigSuccessWithoutUserConfig {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:YES jsonConfigDictionary:nil];
    
    [[self.dataManagerMock reject] saveUser:[OCMArg any]];
    
    [self.dataManagerMock verify];
}

- (void)testProcessedConfigFailure {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:NO jsonConfigDictionary:nil];
    
    [[self.dataManagerMock reject] saveUser:[OCMArg any]];
    
    [self.dataManagerMock verify];
}

- (void)testProcessedConfigSuccessWithUserSameUserConfig {
    LDFlagConfigModel *startingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigA"];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.flagConfig = startingConfig;
    
    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[startingConfig dictionaryValue]];
    XCTAssertTrue(clientUser.flagConfig == startingConfig);     //Should be the same object, unchanged
}

- (void)testProcessedConfigSuccessWithUserDifferentUserConfig {
    LDFlagConfigModel *startingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigA"];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.flagConfig = startingConfig;
    
    LDFlagConfigModel *endingConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldClientManagerTestConfigB"];
    XCTAssertNotNil(endingConfig);

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:[endingConfig dictionaryValue]];
    XCTAssertFalse(clientUser.flagConfig == startingConfig);     //Should not be the same object
    XCTAssertTrue([clientUser.flagConfig isEqualToConfig:endingConfig]);
}

- (void)testSetOnlineYes {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    OCMVerify([self.pollingManagerMock startEventPolling]);
    OCMVerify([self.eventSourceMock onMessage:[OCMArg any]]);
}

- (void)testSetOnlineNo {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;
    clientManager.online = NO;

    OCMVerify([self.pollingManagerMock stopEventPolling]);
    XCTAssertNil([clientManager eventSource]);
}

- (void)testFlushEventsWhenOnline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    NSArray<NSDictionary*> *eventDictionaries = [LDEventModel stubEventDictionariesForUser:[LDClient sharedInstance].ldUser config:config];
    OCMStub([self.dataManagerMock allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(eventDictionaries);
        return YES;
    }]]);

    [LDClientManager sharedInstance].online = YES;
    [[LDClientManager sharedInstance] flushEvents];

    OCMVerify([self.requestManagerMock performEventRequest:[OCMArg isEqual:eventDictionaries]]);
}

- (void)testFlushEventsWhenOffline {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    NSArray<NSDictionary*> *eventDictionaries = [LDEventModel stubEventDictionariesForUser:[LDClient sharedInstance].ldUser config:config];
    OCMStub([self.dataManagerMock allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(eventDictionaries);
        return YES;
    }]]);
    [[self.requestManagerMock reject] performEventRequest:[OCMArg any]];
    [[self.dataManagerMock reject] allEventDictionaries:[OCMArg any]];

    [[LDClientManager sharedInstance] flushEvents];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testClientUnauthorizedPosted {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    [[clientUnauthorizedObserver expect] notificationWithName: kLDClientUnauthorizedNotification object:[OCMArg any]];

    id serverUnavailableObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:serverUnavailableObserver name:kLDServerConnectionUnavailableNotification object:nil];
    [[serverUnavailableObserver expect] notificationWithName: kLDServerConnectionUnavailableNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler errorHandler;
    OCMStub([self.eventSourceMock onError:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    OCMStub([self.eventSourceMock onError:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }
    messageHandler([LDEvent stubPingEvent]);

    OCMVerify([self.requestManagerMock performFeatureFlagRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        LDUserModel *userFromRequest = (LDUserModel*)obj;
        return [user isEqual:userFromRequest];
    }]]);
}

- (void)testSSEPutEventSuccess {
    id userUpdatedNotificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:userUpdatedNotificationObserver name:kLDUserUpdatedNotification object:nil];
    [[userUpdatedNotificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    id userNoChangeNotificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:userNoChangeNotificationObserver name:kLDUserNoChangeNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDFlagConfigModel *targetFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls"];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:userUpdatedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:userNoChangeNotificationObserver];
    };

    [LDClientManager sharedInstance].online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    [[self.dataManagerMock expect] saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        LDUserModel *savedUser = obj;
        XCTAssertTrue([savedUser.flagConfig isEqualToConfig:targetFlagConfig]);
        return YES;
    }]];
    
    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-excludeNulls"];

    messageHandler(put);

    [self.dataManagerMock verify];
}

- (void)testSSEPutResultedInNoChange {
    id userUpdatedNotificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:userUpdatedNotificationObserver name:kLDUserUpdatedNotification object:nil];

    id userNoChangeNotificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:userNoChangeNotificationObserver name:kLDUserNoChangeNotification object:nil];
    [[userNoChangeNotificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    OCMStub([flagConfigMock isEqualToConfig:[OCMArg any]]).andReturn(YES);
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock expect] saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        LDUserModel *savedUser = obj;
        XCTAssertEqualObjects(savedUser, user);
        return YES;
    }]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:userUpdatedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:userNoChangeNotificationObserver];
        [flagConfigMock stopMocking];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    //NOTE: Because the flag config mock will return YES on a config comparison, the put here doesn't matter
    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];

    messageHandler(put);

    [self.dataManagerMock verify];
}

- (void)testSSEPutEventFailedNilData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.flagConfig;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];
    put.data = nil;

    messageHandler(put);

    XCTAssertTrue([user.flagConfig isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEPutEventFailedEmptyData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.flagConfig;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];
    put.data = @"";

    messageHandler(put);

    XCTAssertTrue([user.flagConfig isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEPutEventFailedInvalidData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.flagConfig;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];
    put.data = @"{\"someInvalidData\":}";

    messageHandler(put);

    XCTAssertTrue([user.flagConfig isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEUnrecognizedEvent {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    LDFlagConfigModel *targetFlagConfig = user.flagConfig;

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    clientManager.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:@"someUnrecognizedEvent" fromJsonFileNamed:@"featureFlags"];

    messageHandler(put);

    XCTAssertTrue([user.flagConfig isEqualToConfig: targetFlagConfig]);
    OCMVerifyAll(notificationObserver);
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEPatchEventSuccess {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    OCMStub([flagConfigMock hasFeaturesEqualToDictionary:[OCMArg any]]).andReturn(NO);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

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
    OCMVerify([self.dataManagerMock saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEPatchFailedNilData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] addOrReplaceFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEPatchFailedEmptyData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] addOrReplaceFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEPatchFailedInvalidData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] addOrReplaceFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEDeleteEventSuccess {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    OCMStub([flagConfigMock hasFeaturesEqualToDictionary:[OCMArg any]]).andReturn(NO);

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

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
    OCMVerify([self.dataManagerMock saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEDeleteFailedNilData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] deleteFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEDeleteFailedEmptyData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] deleteFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
}

- (void)testSSEDeleteFailedInvalidData {
    id notificationObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any]];

    __block LDEventSourceEventHandler messageHandler;
    OCMStub([self.eventSourceMock onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]]);

    id flagConfigMock = OCMClassMock([LDFlagConfigModel class]);
    [[flagConfigMock reject] deleteFromDictionary:[OCMArg any]];
    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    user.flagConfig = flagConfigMock;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

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
    OCMVerify(self.dataManagerMock);
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

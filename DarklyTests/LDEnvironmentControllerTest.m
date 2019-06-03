//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDEnvironmentController.h"
#import "LDUserBuilder.h"
#import "OCMock.h"
#import "LDRequestManager.h"
#import "LDDataManager.h"
#import "LDPollingManager.h"
#import "LDEventModel.h"
#import "LDEventModel+Testable.h"
#import "LDEnvironmentController+EventSource.h"
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
#import "NSDictionary+LaunchDarkly.h"
#import "LDEnvironmentController+Testable.h"
#import "LDUtil.h"

extern NSString * _Nonnull const kLDFlagConfigValueKeyValue;
extern NSString * _Nonnull const kLDFlagConfigValueKeyVersion;
extern NSString * _Nonnull const kLDStreamPath;

NSString *const mockMobileKey = @"mockMobileKey";
NSString *const kFeaturesJsonDictionary = @"featuresJsonDictionary";
NSString *const kBoolFlagKey = @"isABawler";

@interface LDEnvironmentController (LDEnvironmentControllerTest)
-(void)startPolling;
-(void)stopPolling;
-(void)configureEventSource;
-(void)syncWithServerForEvents;
-(void)syncWithServerForConfig;
-(void)processedEvents:(BOOL)success jsonEventArray:(NSArray*)jsonEventArray responseDate:(NSDate*)responseDate;
-(void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary;
-(void)willEnterBackground;
-(void)willEnterForeground;
- (void)backgroundFetchInitiated;
@end

@interface LDEnvironmentControllerTest : DarklyXCTestCase
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) NSString *encodedUserString;
@property (nonatomic, strong) NSData *encodedUserData;
@property (nonatomic, strong) NSArray<NSDictionary*> *events;
@property (nonatomic, strong) NSArray<NSString*> *trackedKeys;
@property (nonatomic, strong) LDEnvironmentController *environmentController;
@property (nonatomic) id requestManagerMock;
@property (nonatomic) id dataManagerMock;
@property (nonatomic) id pollingManagerMock;
@property (nonatomic) id eventSourceMock;
@property (nonatomic, strong) NSDictionary *notificationUserInfo;

@end

@implementation LDEnvironmentControllerTest

- (void)setUp {
    [super setUp];
    
    self.config = [[LDConfig alloc] initWithMobileKey:mockMobileKey];
    self.config.flushInterval = @(30);

    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    NSString *userJsonString = [[self.user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString];
    self.encodedUserString = [LDUtil base64UrlEncodeString:userJsonString];
    self.encodedUserData = [userJsonString dataUsingEncoding:NSUTF8StringEncoding];

    self.events = [LDEventModel stubEventDictionariesForUser:self.user config:self.config];
    NSArray *emptyArray = [NSArray array];
    self.trackedKeys = emptyArray;

    self.requestManagerMock = [OCMockObject niceMockForClass:[LDRequestManager class]];
    [[[self.requestManagerMock stub] andReturn:self.requestManagerMock] requestManagerForMobileKey:[OCMArg any] config:[OCMArg any] delegate:[OCMArg any] callbackQueue:[OCMArg any]];

    self.dataManagerMock = [OCMockObject niceMockForClass:[LDDataManager class]];

    self.pollingManagerMock = [OCMockObject niceMockForClass:[LDPollingManager class]];
    [[[self.pollingManagerMock stub] andReturn:self.pollingManagerMock] sharedInstance];

    self.eventSourceMock = [OCMockObject niceMockForClass:[LDEventSource class]];
    [[[self.eventSourceMock stub] andReturn: self.eventSourceMock] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];

    self.environmentController = [LDEnvironmentController controllerWithMobileKey:mockMobileKey config:self.config user:self.user dataManager:self.dataManagerMock trackedKeys:self.trackedKeys];
    self.notificationUserInfo = @{kLDNotificationUserInfoKeyMobileKey: mockMobileKey};
}

- (void)tearDown {
    [[NSNotificationCenter defaultCenter] removeObserver:self.environmentController];   //There is some test pollution without this. environmentController is not dealloc'd right away when set to nil
    [self.requestManagerMock stopMocking];
    [self.dataManagerMock stopMocking];
    [self.pollingManagerMock stopMocking];
    [self.eventSourceMock stopMocking];
    self.requestManagerMock = nil;
    self.dataManagerMock = nil;
    self.pollingManagerMock = nil;
    self.eventSourceMock = nil;
    [super tearDown];
}

#pragma mark - Lifecycle

-(void)testInitAndConstructor {
    id notificationCenterMock = [OCMockObject niceMockForClass:[NSNotificationCenter class]];
    [[[notificationCenterMock stub] andReturn:notificationCenterMock] defaultCenter];
    [[notificationCenterMock expect] addObserver:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((LDEnvironmentController*)obj).mobileKey isEqual:self.config.mobileKey];
    }] selector:@selector(willEnterForeground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[notificationCenterMock expect] addObserver:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((LDEnvironmentController*)obj).mobileKey isEqual:self.config.mobileKey];
    }] selector:@selector(willEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    [[notificationCenterMock expect] addObserver:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((LDEnvironmentController*)obj).mobileKey isEqual:self.config.mobileKey];
    }] selector:@selector(backgroundFetchInitiated) name:kLDBackgroundFetchInitiated object:nil];
    [[notificationCenterMock expect] addObserver:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((LDEnvironmentController*)obj).mobileKey isEqual:self.config.mobileKey];
    }] selector:@selector(syncWithServerForConfig) name:kLDFlagConfigTimerFiredNotification object:nil];
    [[notificationCenterMock expect] addObserver:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [((LDEnvironmentController*)obj).mobileKey isEqual:self.config.mobileKey];
    }] selector:@selector(syncWithServerForEvents) name:kLDEventTimerFiredNotification object:nil];
    self.cleanup = ^{
        [notificationCenterMock stopMocking];
    };

    self.environmentController = [LDEnvironmentController controllerWithMobileKey:mockMobileKey config:self.config user:self.user dataManager:self.dataManagerMock trackedKeys:self.trackedKeys];

    XCTAssertEqualObjects(self.environmentController.mobileKey, self.config.mobileKey);
    XCTAssertEqualObjects(self.environmentController.config, self.config);
    XCTAssertEqualObjects(self.environmentController.user, self.user);
    XCTAssertEqualObjects(self.environmentController.dataManager, self.dataManagerMock);
    XCTAssertEqualObjects(self.environmentController.requestManager, self.requestManagerMock);
    [notificationCenterMock verify];
}

#pragma mark - Control

- (void)testSetOnline_yes_streaming {
    [[self.pollingManagerMock expect] startEventPollingUsingConfig:self.config isOnline:YES];
    self.eventSourceMock = nil;
    self.eventSourceMock = [OCMockObject mockForClass:[LDEventSource class]];
    [[[self.eventSourceMock expect] andReturn:self.eventSourceMock] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    [[self.eventSourceMock expect] onMessage:[OCMArg any]];
    [[self.eventSourceMock expect] onError:[OCMArg any]];
    [[self.eventSourceMock expect] open];
    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any] isOnline:[OCMArg any]];

    self.environmentController.online = YES;

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.requestManagerMock verify];
}

- (void)testSetOnline_yes_polling {
    self.config.streaming = NO;
    [[self.pollingManagerMock expect] startEventPollingUsingConfig:self.config isOnline:YES];
    [[self.eventSourceMock reject] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    [[self.eventSourceMock reject] onMessage:[OCMArg any]];
    [[self.eventSourceMock reject] onError:[OCMArg any]];
    [[self.requestManagerMock expect] performFeatureFlagRequest:self.user isOnline:YES];
    [[self.pollingManagerMock expect] startFlagConfigPollingUsingConfig:self.config isOnline:YES];

    self.environmentController.online = YES;

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.requestManagerMock verify];
}

- (void)testSetOnline_no_streaming {
    self.environmentController.online = YES;
    [[self.pollingManagerMock expect] stopEventPolling];
    [[self.eventSourceMock expect] close];
    [[self.pollingManagerMock reject] stopFlagConfigPolling];

    self.environmentController.online = NO;

    XCTAssertNil([self.environmentController eventSource]);
    [self.eventSourceMock verify];
    [self.pollingManagerMock verify];
}

- (void)testSetOnline_no_polling {
    self.config.streaming = NO;
    [[self.requestManagerMock expect] performFeatureFlagRequest:self.user isOnline:YES];
    self.environmentController.online = YES;
    [[self.pollingManagerMock expect] stopEventPolling];
    [[self.eventSourceMock reject] close];
    [[self.pollingManagerMock expect] stopFlagConfigPolling];

    self.environmentController.online = NO;

    XCTAssertNil([self.environmentController eventSource]);
    [self.eventSourceMock verify];
    [self.pollingManagerMock verify];
}

- (void)testStartPolling_online {
    [[self.pollingManagerMock expect] startEventPollingUsingConfig:self.config isOnline:YES];
    [[self.eventSourceMock expect] onMessage:[OCMArg isNotNil]];

    self.environmentController.online = YES;  //This triggers startPolling

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
}

- (void)testStartPolling_offline {
    self.environmentController.online = NO;
    [[self.pollingManagerMock reject] startEventPollingUsingConfig:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController startPolling];

    [self.pollingManagerMock verify];
    XCTAssertNil(self.environmentController.eventSource);
}

- (void)testStopPolling_streaming {
    self.environmentController.online = YES;    //triggers startPolling
    [[self.pollingManagerMock expect] stopEventPolling];
    [[self.eventSourceMock expect] close];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    [[self.dataManagerMock expect] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        ((void (^)(NSArray *))obj)(self.events);
        return YES;
    }]];
    [[self.requestManagerMock expect] performEventRequest:self.events isOnline:YES];

    [self.environmentController stopPolling];

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.dataManagerMock verify];
    [self.requestManagerMock verify];
    XCTAssertNil(self.environmentController.eventSource);
}

- (void)testStopPolling_polling {
    self.config.streaming = NO;
    self.environmentController.online = YES;    //triggers startPolling
    [[self.pollingManagerMock expect] stopEventPolling];
    [[self.pollingManagerMock expect] stopFlagConfigPolling];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    [[self.dataManagerMock expect] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        ((void (^)(NSArray *))obj)(self.events);
        return YES;
    }]];
    [[self.requestManagerMock expect] performEventRequest:self.events isOnline:YES];

    [self.environmentController stopPolling];

    [self.pollingManagerMock verify];
    [self.dataManagerMock verify];
    [self.requestManagerMock verify];
    XCTAssertNil(self.environmentController.eventSource);
}

- (void)testWillEnterBackground_streaming {
    self.environmentController.online = YES;    //triggers startPolling
    [[self.pollingManagerMock expect] suspendEventPolling];
    [[self.eventSourceMock expect] close];
    [[self.pollingManagerMock reject] suspendFlagConfigPolling];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    [[self.dataManagerMock expect] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        ((void (^)(NSArray *))obj)(self.events);
        return YES;
    }]];
    [[self.requestManagerMock expect] performEventRequest:self.events isOnline:YES];
    NSDate *triggerDate = [NSDate date];

    [self.environmentController willEnterBackground];

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.dataManagerMock verify];
    XCTAssertTrue([self.environmentController.backgroundTime isWithinTimeInterval:1.0 ofDate:triggerDate]);
}

- (void)testWillEnterBackground_polling {
    self.config.streaming = NO;
    self.environmentController.online = YES;    //triggers startPolling
    [[self.pollingManagerMock expect] suspendEventPolling];
    [[self.eventSourceMock reject] close];
    [[self.pollingManagerMock expect] suspendFlagConfigPolling];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    [[self.dataManagerMock expect] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        ((void (^)(NSArray *))obj)(self.events);
        return YES;
    }]];
    [[self.requestManagerMock expect] performEventRequest:self.events isOnline:YES];
    NSDate *triggerDate = [NSDate date];

    [self.environmentController willEnterBackground];

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.dataManagerMock verify];
    XCTAssertTrue([self.environmentController.backgroundTime isWithinTimeInterval:1.0 ofDate:triggerDate]);
}

- (void)testWillEnterForeground_online_streaming {
    self.environmentController.online = YES;
    [self.environmentController willEnterBackground];
    [[self.pollingManagerMock expect] resumeEventPollingWhenIsOnline:YES];
    [[self.eventSourceMock expect] onMessage:[OCMArg any]];
    [[self.eventSourceMock expect] onError:[OCMArg any]];
    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController willEnterForeground];

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.requestManagerMock verify];
}

- (void)testWillEnterForeground_online_polling {
    self.config.streaming = NO;
    self.environmentController.online = YES;
    [self.environmentController willEnterBackground];
    [[self.pollingManagerMock expect] resumeEventPollingWhenIsOnline:YES];
    [[self.eventSourceMock reject] onMessage:[OCMArg any]];
    [[self.eventSourceMock reject] onError:[OCMArg any]];
    [[self.pollingManagerMock expect] resumeFlagConfigPollingWhenIsOnline:YES];
    //Just going back online won't trigger a flag request here. If the timer fires in the background, it will trigger a flag request on return to the foreground. Can't simulate that here.

    [self.environmentController willEnterForeground];

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
}

- (void)testWillEnterForeground_offline {
    self.environmentController.online = NO;
    [self.environmentController willEnterBackground];
    [[self.pollingManagerMock reject] resumeEventPollingWhenIsOnline:[OCMArg any]];
    [[self.eventSourceMock reject] onMessage:[OCMArg any]];
    [[self.eventSourceMock reject] onError:[OCMArg any]];
    [[self.pollingManagerMock reject] resumeFlagConfigPollingWhenIsOnline:[OCMArg any]];
    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController willEnterForeground];

    [self.pollingManagerMock verify];
    [self.eventSourceMock verify];
    [self.requestManagerMock verify];
}

#pragma mark - Streaming

- (void)testEventSourceConfigured_getMethod {
    [self.eventSourceMock stopMocking];
    self.eventSourceMock = [OCMockObject niceMockForClass:[LDEventSource class]];
    __block NSURL *streamUrl;
    __block NSString *streamConnectMethod;
    __block NSData *streamConnectData;
    [[[self.eventSourceMock expect] andReturn:self.eventSourceMock] eventSourceWithURL:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    }]];
    [[self.eventSourceMock expect] open];

    self.environmentController.online = YES;

    XCTAssertTrue([[streamUrl pathComponents] containsObject:kLDStreamPath]);
    XCTAssertFalse([[streamUrl pathComponents] containsObject:@"mping"]);
    XCTAssertTrue([[streamUrl lastPathComponent] isEqualToString:self.encodedUserString]);
    XCTAssertTrue(streamConnectMethod == nil || [streamConnectMethod isEqualToString:@"GET"]);
    XCTAssertNil(streamConnectData);
    [self.eventSourceMock verify];
}

- (void)testEventSourceConfigured_reportMethod {
    self.config.useReport = YES;
    [self.eventSourceMock stopMocking];
    self.eventSourceMock = [OCMockObject niceMockForClass:[LDEventSource class]];
    __block NSURL *streamUrl;
    __block NSString *streamConnectMethod;
    __block NSData *streamConnectData;
    [[[self.eventSourceMock expect]  andReturn:self.eventSourceMock] eventSourceWithURL:[OCMArg checkWithBlock:^BOOL(id obj) {
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
    }]];
    [[self.eventSourceMock expect] open];

    self.environmentController.online = YES;

    XCTAssertTrue([[streamUrl lastPathComponent] isEqualToString:kLDStreamPath]);
    XCTAssertFalse([[streamUrl pathComponents] containsObject:@"mping"]);
    XCTAssertTrue([streamConnectMethod isEqualToString:kHTTPMethodReport]);
    XCTAssertTrue([streamConnectData isEqualToData:self.encodedUserData]);
}

- (void)testEventSourceNotCreated_offline {
    [[self.eventSourceMock reject] open];

    [self.environmentController startPolling];

    XCTAssertNil(self.environmentController.eventSource);
    [self.eventSourceMock verify];
}

- (void)testConfigureEventSource_offline {
    [[self.eventSourceMock reject] open];

    [self.environmentController configureEventSource];

    XCTAssertNil(self.environmentController.eventSource);
    [self.eventSourceMock verify];
}

- (void)testEventSourceRemainsConstantAcrossStartPollingCalls {
    int numTries = 5;
    self.eventSourceMock = nil;
    self.eventSourceMock = [OCMockObject mockForClass:[LDEventSource class]];
    [[[self.eventSourceMock expect] andReturn:self.eventSourceMock] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    [[self.eventSourceMock expect] onMessage:[OCMArg any]];
    [[self.eventSourceMock expect] onError:[OCMArg any]];
    [[self.eventSourceMock expect] open];
    self.environmentController.online = YES;

    [[self.eventSourceMock reject] eventSourceWithURL:[OCMArg any] httpHeaders:[OCMArg any] connectMethod:[OCMArg any] connectBody:[OCMArg any]];
    for (int i = 0; i < numTries; i++) {
        [self.environmentController startPolling];
    }
    [self.eventSourceMock verify];
}

- (void)testEventSourceRemovedOnStopPolling {
    self.environmentController.online = YES;
    [[self.eventSourceMock expect] close];

    [self.environmentController stopPolling];

    XCTAssertNil(self.environmentController.eventSource);
    [self.eventSourceMock verify];
}

- (void)testEventSourceRemainsConstantAcrossWillEnterForegroundCalls {
    int numTries = 5;
    self.environmentController.online = YES;
    [self.environmentController startPolling];
    XCTAssertNotNil(self.environmentController.eventSource);

    LDEventSource *eventSource = [self.environmentController eventSource];
    for (int i = 0; i < numTries; i++) {
        [self.environmentController willEnterForeground];
        XCTAssert(eventSource == self.environmentController.eventSource);
    }
}

- (void)testSSEPingEvent {
    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    self.environmentController.online = YES;
    [[self.requestManagerMock expect] performFeatureFlagRequest:self.user isOnline:YES];

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) {
        return;
    }
    messageHandler([LDEvent stubPingEvent]);

    [self.requestManagerMock verify];
}

- (void)testSSEPutEventSuccess {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];
    __block NSDictionary *featureFlagsChangedNotificationUserInfo;
    [[notificationObserver expect] notificationWithName:kLDFeatureFlagsChangedNotification object:[OCMArg any] userInfo:[OCMArg checkWithBlock:^BOOL(id obj) {
        featureFlagsChangedNotificationUserInfo = obj;
        return YES;
    }]];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls"];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    [[self.dataManagerMock expect] saveUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        LDUserModel *savedUser = obj;
        XCTAssertTrue([savedUser.flagConfig isEqualToConfig:targetFlagConfig]);
        return YES;
    }]];

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags-excludeNulls"];

    messageHandler(put);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertFalse(self.user.flagConfig == originalFlagConfig);
    [self.dataManagerMock verify];
    [notificationObserver verify];
    XCTAssertNotNil(featureFlagsChangedNotificationUserInfo);
    if (featureFlagsChangedNotificationUserInfo != nil) {
        XCTAssertEqualObjects(featureFlagsChangedNotificationUserInfo[kLDNotificationUserInfoKeyMobileKey], mockMobileKey);
        NSSet *changedFlagKeys = [NSSet setWithArray:[originalFlagConfig differingFlagKeysFromConfig:targetFlagConfig]];
        XCTAssertEqualObjects([NSSet setWithArray:featureFlagsChangedNotificationUserInfo[kLDNotificationUserInfoKeyFlagKeys]], changedFlagKeys);
    }
}

- (void)testSSEPutResultedInNoChange {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [originalFlagConfig copy];

    [[self.dataManagerMock expect] saveUser:self.user];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];

    messageHandler(put);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig: targetFlagConfig]);
    XCTAssertFalse(self.user.flagConfig == originalFlagConfig);
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPutEventFailedNilData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [originalFlagConfig copy];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];
    put.data = nil;

    messageHandler(put);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig: targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPutEventFailedEmptyData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [originalFlagConfig copy];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];
    put.data = @"";

    messageHandler(put);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig: targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPutEventFailedInvalidData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [originalFlagConfig copy];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:kLDEventTypePut fromJsonFileNamed:@"featureFlags"];
    put.data = @"{\"someInvalidData\":}";

    messageHandler(put);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig: targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPatchEventSuccess {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];
    __block NSDictionary *featureFlagsChangedNotificationUserInfo;
    [[notificationObserver expect] notificationWithName:kLDFeatureFlagsChangedNotification object:[OCMArg any] userInfo:[OCMArg checkWithBlock:^BOOL(id obj) {
        featureFlagsChangedNotificationUserInfo = obj;
        return YES;
    }]];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };
    self.environmentController.online = YES;

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldEnvironmentControllerTestPatchIsANumber"];
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig applySSEEvent:patch];

    [[self.dataManagerMock expect] saveUser:self.user];

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    messageHandler(patch);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object with the new flagConfigValue
    [self.dataManagerMock verify];
    [notificationObserver verify];
    XCTAssertNotNil(featureFlagsChangedNotificationUserInfo);
    if (featureFlagsChangedNotificationUserInfo != nil) {
        XCTAssertEqualObjects(featureFlagsChangedNotificationUserInfo[kLDNotificationUserInfoKeyMobileKey], mockMobileKey);
        XCTAssertEqualObjects([NSSet setWithArray:featureFlagsChangedNotificationUserInfo[kLDNotificationUserInfoKeyFlagKeys]], [NSSet setWithArray:@[kLDFlagKeyIsANumber]]);
    }
}

- (void)testSSEPatchResultedInNoChange {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    //By pulling the patch from the existing flagConfig, the patch should not be applied, resulting in no change to the flagConfig
    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch flagKey:kLDFlagKeyIsANumber withDataDictionary:[self.user.flagConfig.featuresJsonDictionary[kLDFlagKeyIsANumber] dictionaryValue]];
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    messageHandler(patch);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object with the new flagConfigValue
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPatchFailedNilData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldEnvironmentControllerTestPatchIsANumber"];
    patch.data = nil;

    messageHandler(patch);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object with the new flagConfigValue
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPatchFailedEmptyData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldEnvironmentControllerTestPatchIsANumber"];
    patch.data = @"";

    messageHandler(patch);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object with the new flagConfigValue
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEPatchFailedInvalidData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *patch = [LDEvent stubEvent:kLDEventTypePatch fromJsonFileNamed:@"ldEnvironmentControllerTestPatchIsANumber"];
    patch.data = @"{\"someInvalidData\":}";

    messageHandler(patch);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object with the new flagConfigValue
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEDeleteEventSuccess {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldEnvironmentControllerTestDeleteIsANumber"];
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig applySSEEvent:delete];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    [[self.dataManagerMock expect] saveUser:self.user];

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    messageHandler(delete);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertNil([self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANumber]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object without the flagConfigValue
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEDeleteResultedInNoChange {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    //By pulling the delete from the existing flagConfig, the delete should not be applied, resulting in no change to the flagConfig
    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete flagKey:kLDFlagKeyIsANumber withDataDictionary:[self.user.flagConfig.featuresJsonDictionary[kLDFlagKeyIsANumber] dictionaryValue]];
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    messageHandler(delete);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertNotNil([self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANumber]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEDeleteFailedNilData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldEnvironmentControllerTestDeleteIsANumber"];
    delete.data = nil;

    messageHandler(delete);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertNotNil([self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANumber]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEDeleteFailedEmptyData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldEnvironmentControllerTestDeleteIsANumber"];
    delete.data = @"";

    messageHandler(delete);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertNotNil([self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANumber]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEDeleteFailedInvalidData {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [self.user.flagConfig copy];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *delete = [LDEvent stubEvent:kLDEventTypeDelete fromJsonFileNamed:@"ldEnvironmentControllerTestDeleteIsANumber"];
    delete.data = @"{\"someInvalidData\":}";

    messageHandler(delete);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:targetFlagConfig]);
    XCTAssertNotNil([self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANumber]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);   //same object
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testSSEUnrecognizedEvent {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserNoChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDUserUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDFeatureFlagsChangedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    __block LDEventSourceEventHandler messageHandler;
    [[self.eventSourceMock stub] onMessage:[OCMArg checkWithBlock:^BOOL(id obj) {
        messageHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;
    LDFlagConfigModel *targetFlagConfig = [originalFlagConfig copy];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(messageHandler);
    if (!messageHandler) { return; }

    LDEvent *put = [LDEvent stubEvent:@"someUnrecognizedEvent" fromJsonFileNamed:@"featureFlags"];

    messageHandler(put);

    XCTAssertTrue([self.user.flagConfig isEqualToConfig: targetFlagConfig]);
    XCTAssertTrue(self.user.flagConfig == originalFlagConfig);
    [self.dataManagerMock verify];
    [notificationObserver verify];
}

- (void)testClientUnauthorizedPosted {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDClientUnauthorizedNotification object:nil];
    [[notificationObserver expect] notificationWithName: kLDClientUnauthorizedNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDServerConnectionUnavailableNotification object:nil];
    [[notificationObserver expect] notificationWithName: kLDServerConnectionUnavailableNotification object:[OCMArg any] userInfo:self.notificationUserInfo];

    __block LDEventSourceEventHandler errorHandler;
    [[self.eventSourceMock stub] onError:[OCMArg checkWithBlock:^BOOL(id obj) {
        errorHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(errorHandler);
    if (!errorHandler) { return; }
    errorHandler([LDEvent stubUnauthorizedEvent]);

    [notificationObserver verify];
}

- (void)testClientUnauthorizedNotPosted {
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDClientUnauthorizedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDServerConnectionUnavailableNotification object:nil];
    [[notificationObserver expect] notificationWithName: kLDServerConnectionUnavailableNotification object:[OCMArg any] userInfo:self.notificationUserInfo];

    __block LDEventSourceEventHandler errorHandler;
    [[self.eventSourceMock stub] onError:[OCMArg checkWithBlock:^BOOL(id obj) {
        errorHandler = (LDEventSourceEventHandler)obj;
        return YES;
    }]];

    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    self.environmentController.online = YES;

    XCTAssertNotNil(errorHandler);
    if (!errorHandler) { return; }
    errorHandler([LDEvent stubErrorEvent]);

    [notificationObserver verify];
}

#pragma mark - Polling

- (void)testFlagConfigTimerFiredNotification {
    self.environmentController.online = YES;
    [[self.requestManagerMock expect] performFeatureFlagRequest:self.user isOnline:self.environmentController.isOnline];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDFlagConfigTimerFiredNotification object:nil];

    [self.requestManagerMock verify];
}

- (void)testSyncWithServerForConfig {
    self.environmentController.online = YES;
    [[self.requestManagerMock expect] performFeatureFlagRequest:self.user isOnline:self.environmentController.isOnline];

    [self.environmentController syncWithServerForConfig];

    [self.requestManagerMock verify];
}

- (void)testSyncWithServerForConfig_UserDoesNotExist {
    self.environmentController.user = nil;
    self.environmentController.online = YES;
    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController syncWithServerForConfig];

    [self.requestManagerMock verify];
}

- (void)testSyncWithServerForConfig_offline {
    self.environmentController.online = NO;
    [[self.requestManagerMock reject] performFeatureFlagRequest:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController syncWithServerForConfig];

    [self.requestManagerMock verify];
}

#pragma mark - Flag Config Processing Notification

- (void)testProcessedConfig_success_flagConfigChanged {
    id userUpdatedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userUpdatedNotificationObserver name:kLDUserUpdatedNotification object:nil];
    [[userUpdatedNotificationObserver expect] notificationWithName:kLDUserUpdatedNotification object:[OCMArg any] userInfo:self.notificationUserInfo];

    id userNoChangeNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userNoChangeNotificationObserver name:kLDUserNoChangeNotification object:nil];

    id featureFlagsChangedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:featureFlagsChangedNotificationObserver name:kLDFeatureFlagsChangedNotification object:nil];
    __block NSDictionary *featureFlagsChangedNotificationUserInfo;
    [[featureFlagsChangedNotificationObserver expect] notificationWithName:kLDFeatureFlagsChangedNotification object:[OCMArg any] userInfo:[OCMArg checkWithBlock:^BOOL(id obj) {
        featureFlagsChangedNotificationUserInfo = obj;
        return YES;
    }]];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:userUpdatedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:userNoChangeNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:featureFlagsChangedNotificationObserver];
    };

    [[self.dataManagerMock expect] saveUser:self.user];

    LDFlagConfigModel *startingFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldEnvironmentControllerTestConfigA"];
    self.user.flagConfig = startingFlagConfig;
    LDFlagConfigModel *endingFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldEnvironmentControllerTestConfigB"];

    [self.environmentController processedConfig:YES jsonConfigDictionary:[endingFlagConfig dictionaryValue]];

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:endingFlagConfig]);
    [self.dataManagerMock verify];
    [userUpdatedNotificationObserver verify];
    [userNoChangeNotificationObserver verify];
    [featureFlagsChangedNotificationObserver verify];
    XCTAssertNotNil(featureFlagsChangedNotificationUserInfo);
    if (featureFlagsChangedNotificationUserInfo != nil) {
        XCTAssertEqualObjects(featureFlagsChangedNotificationUserInfo[kLDNotificationUserInfoKeyMobileKey], mockMobileKey);
        NSSet *changedFlagKeys = [NSSet setWithArray:[startingFlagConfig differingFlagKeysFromConfig:endingFlagConfig]];
        XCTAssertEqualObjects([NSSet setWithArray:featureFlagsChangedNotificationUserInfo[kLDNotificationUserInfoKeyFlagKeys]], changedFlagKeys);
    }
}

- (void)testProcessedConfig_success_flagConfigUnchanged_trackingContextChanged {
    id userUpdatedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userUpdatedNotificationObserver name:kLDUserUpdatedNotification object:nil];

    id userNoChangeNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userNoChangeNotificationObserver name:kLDUserNoChangeNotification object:nil];
    [[userNoChangeNotificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];

    id featureFlagsChangedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:featureFlagsChangedNotificationObserver name:kLDFeatureFlagsChangedNotification object:nil];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:userUpdatedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:userNoChangeNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:featureFlagsChangedNotificationObserver];
    };


    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;   //the user stub creates feature flags from the "featureFlags" fixture

    //Changing the eventTrackingContext should have no effect on the flagConfig comparison. Changing it here verifies that requirement.
    LDEventTrackingContext *updatedEventTrackingContext = [LDEventTrackingContext contextWithTrackEvents:YES debugEventsUntilDate:[NSDate dateWithTimeIntervalSinceNow:30.0]];
    LDFlagConfigModel *updatedFlagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags" eventTrackingContext:updatedEventTrackingContext];

    [self.environmentController processedConfig:YES jsonConfigDictionary:[updatedFlagConfig dictionaryValue]];

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:originalFlagConfig]);
    [self.dataManagerMock verify];
    [userUpdatedNotificationObserver verify];
    [userNoChangeNotificationObserver verify];
    [featureFlagsChangedNotificationObserver verify];
}

- (void)testProcessedConfig_success_withoutFlagConfig {
    id userUpdatedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userUpdatedNotificationObserver name:kLDUserUpdatedNotification object:nil];

    id userNoChangeNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userNoChangeNotificationObserver name:kLDUserNoChangeNotification object:nil];
    [[userNoChangeNotificationObserver expect] notificationWithName:kLDUserNoChangeNotification object:[OCMArg any] userInfo:self.notificationUserInfo];

    id featureFlagsChangedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:featureFlagsChangedNotificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    id connectionUnavailableNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:connectionUnavailableNotificationObserver name:kLDServerConnectionUnavailableNotification object:nil];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:userUpdatedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:userNoChangeNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:featureFlagsChangedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:connectionUnavailableNotificationObserver];
    };

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;

    [self.environmentController processedConfig:YES jsonConfigDictionary:nil];

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:originalFlagConfig]);
    [self.dataManagerMock verify];
    [userUpdatedNotificationObserver verify];
    [userNoChangeNotificationObserver verify];
    [featureFlagsChangedNotificationObserver verify];
    [connectionUnavailableNotificationObserver verify];
}

- (void)testProcessedConfig_failure {
    id userUpdatedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userUpdatedNotificationObserver name:kLDUserUpdatedNotification object:nil];

    id userNoChangeNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:userNoChangeNotificationObserver name:kLDUserNoChangeNotification object:nil];

    id featureFlagsChangedNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:featureFlagsChangedNotificationObserver name:kLDFeatureFlagsChangedNotification object:nil];

    id connectionUnavailableNotificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:connectionUnavailableNotificationObserver name:kLDServerConnectionUnavailableNotification object:nil];
    [[connectionUnavailableNotificationObserver expect] notificationWithName:kLDServerConnectionUnavailableNotification object:[OCMArg any] userInfo:self.notificationUserInfo];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:userUpdatedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:userNoChangeNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:featureFlagsChangedNotificationObserver];
        [[NSNotificationCenter defaultCenter] removeObserver:connectionUnavailableNotificationObserver];
    };

    LDFlagConfigModel *originalFlagConfig = self.user.flagConfig;

    [[self.dataManagerMock reject] saveUser:[OCMArg any]];

    [self.environmentController processedConfig:NO jsonConfigDictionary:nil];

    XCTAssertTrue([self.user.flagConfig isEqualToConfig:originalFlagConfig]);
    [self.dataManagerMock verify];
    [userUpdatedNotificationObserver verify];
    [userNoChangeNotificationObserver verify];
    [featureFlagsChangedNotificationObserver verify];
    [connectionUnavailableNotificationObserver verify];
}

#pragma mark - Events

- (void)testEventTimerFiredNotification {
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(self.events);
        return YES;
    }]];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    self.environmentController.online = YES;
    [[self.requestManagerMock expect] performEventRequest:self.events isOnline:self.environmentController.isOnline];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDEventTimerFiredNotification object:nil];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testSyncWithServerForEvents_eventsExist {
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(self.events);
        return YES;
    }]];
    self.environmentController.online = YES;
    [[self.requestManagerMock expect] performEventRequest:self.events isOnline:YES];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];

    [self.environmentController syncWithServerForEvents];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testSyncWithServerForEvents_eventsEmpty {
    self.environmentController.online = YES;
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(@[]);
        return YES;
    }]];
    [[self.requestManagerMock reject] performEventRequest:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController syncWithServerForEvents];
    
    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testSyncWithServerForEvents_eventsNil {
    self.environmentController.online = YES;
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(nil);
        return YES;
    }]];
    [[self.requestManagerMock reject] performEventRequest:[OCMArg any] isOnline:[OCMArg any]];

    [self.environmentController syncWithServerForEvents];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testSyncWithServerForEvents_offline {
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(self.events);
        return YES;
    }]];
    [[self.requestManagerMock reject] performEventRequest:[OCMArg any] isOnline:[OCMArg any]];
    [[self.dataManagerMock reject] allEventDictionaries:[OCMArg any]];

    [self.environmentController syncWithServerForEvents];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

- (void)testProcessedEvents_success_withProcessedEvents {
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true"
                                                                                     flagKey:kLDFlagKeyIsABool
                                                                        eventTrackingContext:[LDEventTrackingContext stub]];
    LDEventModel *event = [LDEventModel featureEventWithFlagKey:kFeatureEventKeyStub
                                              reportedFlagValue:flagConfigValue.value
                                                flagConfigValue:flagConfigValue
                                               defaultFlagValue:@(NO)
                                                           user:self.user
                                                     inlineUser:self.config.inlineUserInEvents];
    NSArray *events = @[[event dictionaryValueUsingConfig:self.config]];
    NSDate *headerDate = [NSDateFormatter eventDateHeaderStub];
    [[self.dataManagerMock expect] deleteProcessedEvents:events];
    [[self.dataManagerMock expect] setLastEventResponseDate:headerDate];

    [self.environmentController processedEvents:YES jsonEventArray:events responseDate:headerDate];
    
    [self.dataManagerMock verify];
}

- (void)testProcessedEvents_success_emptyProcessedEvents {
    NSDate *headerDate = [NSDateFormatter eventDateHeaderStub];
    [[self.dataManagerMock expect] deleteProcessedEvents:@[]];
    [[self.dataManagerMock expect] setLastEventResponseDate:headerDate];

    [self.environmentController processedEvents:YES jsonEventArray:@[] responseDate:headerDate];

    [self.dataManagerMock verify];
}

- (void)testProcessedEvents_success_nilProcessedEvents {
    NSDate *headerDate = [NSDateFormatter eventDateHeaderStub];
    [[self.dataManagerMock expect] deleteProcessedEvents:nil];
    [[self.dataManagerMock expect] setLastEventResponseDate:headerDate];

    [self.environmentController processedEvents:YES jsonEventArray:nil responseDate:headerDate];

    [self.dataManagerMock verify];
}

- (void)testProcessedEvents_failure {
    [[self.dataManagerMock reject] deleteProcessedEvents:[OCMArg any]];

    [self.environmentController processedEvents:NO jsonEventArray:nil responseDate:nil];
    
    [self.dataManagerMock verify];
}

- (void)testFlushEventsWhenOnline {
    self.environmentController.online = YES;
    [[self.requestManagerMock expect] performEventRequest:[OCMArg any] isOnline:self.environmentController.isOnline];
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(self.events);
        return YES;
    }]];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.user];

    [self.environmentController flushEvents];

    [self.requestManagerMock verify];
}

- (void)testFlushEventsWhenOffline {
    [[self.dataManagerMock stub] allEventDictionaries:[OCMArg checkWithBlock:^BOOL(id obj) {
        void (^completion)(NSArray *) = obj;
        completion(self.events);
        return YES;
    }]];
    [[self.requestManagerMock reject] performEventRequest:[OCMArg any] isOnline:[OCMArg any]];
    [[self.dataManagerMock reject] allEventDictionaries:[OCMArg any]];

    [self.environmentController flushEvents];

    [self.requestManagerMock verify];
    [self.dataManagerMock verify];
}

@end

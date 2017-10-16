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

@interface LDClientManagerTest : DarklyXCTestCase
@property (nonatomic) id requestManagerMock;
@property (nonatomic) id ldClientMock;
@property (nonatomic) id dataManagerMock;
@property (nonatomic) id pollingManagerMock;
@end


@implementation LDClientManagerTest
@synthesize requestManagerMock;
@synthesize ldClientMock;
@synthesize dataManagerMock;
@synthesize pollingManagerMock;

- (void)setUp {
    [super setUp];
    
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = [[NSUUID UUID] UUIDString];
    userBuilder.email = @"jeff@test.com";

    ldClientMock = [self mockClientWithUser:[userBuilder build]];
    
    requestManagerMock = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([requestManagerMock sharedInstance])).andReturn(requestManagerMock);
    
    dataManagerMock = OCMClassMock([LDDataManager class]);
    OCMStub(ClassMethod([dataManagerMock sharedManager])).andReturn(dataManagerMock);
    
    pollingManagerMock = OCMClassMock([LDPollingManager class]);
    OCMStub(ClassMethod([pollingManagerMock sharedInstance])).andReturn(pollingManagerMock);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [ldClientMock stopMocking];
    [requestManagerMock stopMocking];
    [dataManagerMock stopMocking];
    [pollingManagerMock stopMocking];
}

- (void)testEventSourceCreatedOnStartPolling {
    [[LDClientManager sharedInstance] startPolling];
    XCTAssertNotNil([[LDClientManager sharedInstance] eventSource]);
}

- (void)testEventSourceRemainsConstantAcrossStartPollingCalls {
    int numTries = 5;
    [[LDClientManager sharedInstance] startPolling];
    LDEventSource *eventSource = [[LDClientManager sharedInstance] eventSource];
    XCTAssertNotNil(eventSource);
    for (int i = 0; i < numTries; i++) {
        [[LDClientManager sharedInstance] startPolling];
        XCTAssert(eventSource == [[LDClientManager sharedInstance] eventSource]);
    }
}

- (void)testEventSourceRemovedOnStopPolling {
    [[LDClientManager sharedInstance] startPolling];
    XCTAssertNotNil([[LDClientManager sharedInstance] eventSource]);
    [[LDClientManager sharedInstance] stopPolling];
    XCTAssertNil([[LDClientManager sharedInstance] eventSource]);
}

- (void)testEventSourceCreatedOnWillEnterForeground {
    [[LDClientManager sharedInstance] startPolling];
    XCTAssertNotNil([[LDClientManager sharedInstance] eventSource]);
    [[LDClientManager sharedInstance] willEnterBackground];
    XCTAssertNil([[LDClientManager sharedInstance] eventSource]);
    [[LDClientManager sharedInstance] willEnterForeground];
    XCTAssertNotNil([[LDClientManager sharedInstance] eventSource]);
}

- (void)testEventSourceRemainsConstantAcrossWillEnterForegroundCalls {
    int numTries = 5;
    [[LDClientManager sharedInstance] startPolling];
    LDEventSource *eventSource = [[LDClientManager sharedInstance] eventSource];
    XCTAssertNotNil(eventSource);
    for (int i = 0; i < numTries; i++) {
        [[LDClientManager sharedInstance] willEnterForeground];
        XCTAssert(eventSource == [[LDClientManager sharedInstance] eventSource]);
    }
}

- (void)testSyncWithServerForConfigWhenUserExistsAndOnline {
    [[requestManagerMock expect] performFeatureFlagRequest:[ldClientMock ldUser]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [clientManager syncWithServerForConfig];

    [requestManagerMock verify];
}

- (void)testSyncWithServerForConfigWhenUserDoesNotExist {
    [self mockClientWithUser:nil];
    XCTAssertNil([LDClient sharedInstance].ldUser);
    
    [[requestManagerMock reject] performFeatureFlagRequest:[OCMArg any]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [clientManager syncWithServerForConfig];
}

- (void)testSyncWithServerForConfigWhenOffline {
    [[requestManagerMock reject] performFeatureFlagRequest:[OCMArg any]];

    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];
    
    [clientManager syncWithServerForConfig];
}

- (void)testSyncWithServerForEventsWhenEventsExist {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [dataManagerMock allEventsJsonArray:^(NSArray *array) {
        OCMStub(array).andReturn(testData);
        
        [clientManager syncWithServerForEvents];
        
        OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    }];
}

- (void)testDoNotSyncWithServerForEventsWhenEventsDoNotExist {
    NSData *testData = nil;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
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
        [clientManager setOfflineEnabled:YES];
        [clientManager syncWithServerForEvents];
        
        [requestManagerMock verify];
    }];
}

- (void)testStartPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager startPolling];
    
    OCMVerify([pollingManagerMock startEventPolling]);
}

- (void)testStopPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager stopPolling];
    
    OCMVerify([pollingManagerMock stopEventPolling]);
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

- (void)testProcessedConfigSuccessWithUserConfig {
    NSDictionary *testDictionary = @{@"key":@"value"};
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:YES jsonConfigDictionary:testDictionary];
    
    OCMVerify([dataManagerMock saveUser:[OCMArg any]]);
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
    LDFlagConfigModel *startingConfig = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"ldClientManagerTestConfigA"]];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.config = startingConfig;
    
    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:startingConfig.featuresJsonDictionary];
    XCTAssertTrue(clientUser.config == startingConfig);     //Should be the same object, unchanged
}

- (void)testProcessedConfigSuccessWithUserDifferentUserConfig {
    LDFlagConfigModel *startingConfig = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"ldClientManagerTestConfigA"]];
    XCTAssertNotNil(startingConfig);

    LDUserModel *clientUser = [[LDClient sharedInstance] ldUser];
    clientUser.config = startingConfig;
    
    LDFlagConfigModel *endingConfig = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"ldClientManagerTestConfigB"]];
    XCTAssertNotNil(endingConfig);

    [[LDClientManager sharedInstance] processedConfig:YES jsonConfigDictionary:endingConfig.featuresJsonDictionary];
    XCTAssertFalse(clientUser.config == startingConfig);     //Should not be the same object
    XCTAssertTrue([clientUser.config isEqualToConfig:endingConfig]);
}

#pragma mark - Helpers

- (NSDictionary*)dictionaryFromJsonFileNamed:(NSString *)fileName {
    NSString *filepath = [[NSBundle bundleForClass:[self class]] pathForResource:fileName
                                                                          ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    return [NSJSONSerialization JSONObjectWithData:data
                                           options:kNilOptions
                                             error:&error];
}

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

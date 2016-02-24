//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDClientManager.h"
#import "LDUserBuilder.h"
#import "LDClient.h"
#import <OCMock.h>
#import "LDRequestManager.h"
#import "LDDataManager.h"
#import "LDPollingManager.h"
#import "LDEventModel.h"

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
    userBuilder = [userBuilder withKey:@"jeff@test.com"];
    LDUserModel *user = [userBuilder build];
    
    LDConfigBuilder *configBuilder = [[LDConfigBuilder alloc] init];
    configBuilder = [configBuilder withFlushInterval:30];
    LDConfig *config = [configBuilder build];
    
    ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    OCMStub([ldClientMock ldUser]).andReturn(user);
    OCMStub([ldClientMock ldConfig]).andReturn(config);
    
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

- (void)testSyncWithServerForConfigWhenUserExists {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [clientManager syncWithServerForConfig];

    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg isKindOfClass:[NSString class]]]);
}

- (void)testDoNotSyncWithServerForConfigWhenUserDoesNotExists {
    NSData *testData = nil;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    [clientManager syncWithServerForConfig];
    
    [requestManagerMock verify];
}

- (void)testSyncWithServerForEventsWhenEventsExist {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    [clientManager syncWithServerForEvents];
    
    OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    
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
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];    
    [clientManager syncWithServerForEvents];
    
    [requestManagerMock verify];
}

- (void)testStartPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager startPolling];
    
    OCMVerify([pollingManagerMock startConfigPolling]);
    OCMVerify([pollingManagerMock startEventPolling]);
}

- (void)testStopPolling {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager stopPolling];
    
    OCMVerify([pollingManagerMock stopConfigPolling]);
    OCMVerify([pollingManagerMock stopEventPolling]);
}

- (void)testWillEnterBackground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager willEnterBackground];
    
    OCMVerify([pollingManagerMock suspendConfigPolling]);
    OCMVerify([pollingManagerMock suspendEventPolling]);
}

- (void)testWillEnterForeground {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager willEnterForeground];
    
    OCMVerify([pollingManagerMock resumeConfigPolling]);
    OCMVerify([pollingManagerMock resumeEventPolling]);
}

- (void)testProcessedEventsSuccessWithProcessedEvents {
    int eventIntervalMillis = 10;
    LDEventModel *event = [[LDEventModel alloc] init];
    [event initFeatureEventWithKey:@"blah" keyValue:NO defaultKeyValue:NO userValue:[[LDClient sharedInstance] ldUser]];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[[event dictionaryValue]] options:NSJSONWritingPrettyPrinted error:nil];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:YES jsonEventArray:data eventIntervalMillis:eventIntervalMillis];
    
    OCMVerify([dataManagerMock deleteProcessedEvents:[OCMArg any]]);
}

- (void)testProcessedEventsSuccessWithoutProcessedEvents {
    int eventIntervalMillis = 10;
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[] options:NSJSONWritingPrettyPrinted error:nil];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:YES jsonEventArray:data eventIntervalMillis:eventIntervalMillis];
    
    [[dataManagerMock reject] deleteProcessedEvents:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedEventsFailure {
    int eventIntervalMillis = 10;
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedEvents:NO jsonEventArray:nil eventIntervalMillis:eventIntervalMillis];
    
    [[dataManagerMock reject] deleteProcessedEvents:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedConfigSuccessWithUserConfig {
    int configIntervalMillis = 10;
    
    NSDictionary *testDictionary = @{@"key":@"value"};
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:YES jsonConfigDictionary:testDictionary configIntervalMillis:configIntervalMillis];
    
    OCMVerify([dataManagerMock saveUser:[OCMArg any]]);
}

- (void)testProcessedConfigSuccessWithoutUserConfig {
    int configIntervalMillis = 10;
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:YES jsonConfigDictionary:nil configIntervalMillis:configIntervalMillis];
    
    [[dataManagerMock reject] saveUser:[OCMArg any]];
    
    [dataManagerMock verify];
}

- (void)testProcessedConfigFailure {
    int configIntervalMillis = 10;
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager processedConfig:NO jsonConfigDictionary:nil configIntervalMillis:configIntervalMillis];
    
    [[dataManagerMock reject] saveUser:[OCMArg any]];
    
    [dataManagerMock verify];
}

@end

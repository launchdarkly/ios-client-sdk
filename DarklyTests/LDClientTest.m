//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDClient.h"
#import "LDDataManager.h"
#import "LDUserModel.h"
#import "LDFlagConfigModel.h"
#import "LDUserBuilder.h"
#import "LDPollingManager.h"
#import "LDUserBuilder+Testable.h"

#import "OCMock.h"
#import <OHHTTPStubs/OHHTTPStubs.h>

typedef void(^MockLDClientDelegateCallbackBlock)(void);

@interface MockLDClientDelegate : NSObject <ClientDelegate>
@property (nonatomic, assign) NSInteger userDidUpdateCallCount;
@property (nonatomic, assign) NSInteger userUnchangedCallCount;
@property (nonatomic, assign) NSInteger serverConnectionUnavailableCallCount;
@property (nonatomic, strong) MockLDClientDelegateCallbackBlock userDidUpdateCallback;
@property (nonatomic, strong) MockLDClientDelegateCallbackBlock userUnchangedCallback;
@property (nonatomic, strong) MockLDClientDelegateCallbackBlock serverUnavailableCallback;
@end

@implementation MockLDClientDelegate
-(instancetype)init {
    self = [super init];
    
    return self;
}

-(void)userDidUpdate {
    self.userDidUpdateCallCount = [self processCallbackWithCount:self.userDidUpdateCallCount block:self.userDidUpdateCallback];
}

-(void)userUnchanged {
    self.userUnchangedCallCount = [self processCallbackWithCount:self.userUnchangedCallCount block:self.userUnchangedCallback];
}

-(void)serverConnectionUnavailable {
    self.serverConnectionUnavailableCallCount = [self processCallbackWithCount:self.serverConnectionUnavailableCallCount block:self.serverUnavailableCallback];
}

-(NSInteger)processCallbackWithCount:(NSInteger)callbackCount block:(MockLDClientDelegateCallbackBlock)callbackBlock {
    callbackCount += 1;
    if (!callbackBlock) { return callbackCount; }
    callbackBlock();
    return callbackCount;
}
@end

@interface LDClientTest : DarklyXCTestCase <ClientDelegate>
@property (nonatomic, strong) XCTestExpectation *userConfigUpdatedNotificationExpectation;
@property (nonatomic, assign) BOOL configureUser;
@end

NSString *const kFallbackString = @"fallbackString";
NSString *const kTargetValueString = @"someString";
NSString *const kTestMobileKey = @"testMobileKey";

@implementation LDClientTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.configureUser = NO;
}

- (void)tearDown {
    [[LDClient sharedInstance] stopClient];
    [LDClient sharedInstance].delegate = nil;
    [OHHTTPStubs removeAllStubs];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.configureUser = NO;
    self.userConfigUpdatedNotificationExpectation = nil;
    [super tearDown];
}

- (void)testSharedInstance {
    LDClient *first = [LDClient sharedInstance];
    LDClient *second = [LDClient sharedInstance];
    XCTAssertEqual(first, second);
}

- (void)testStartWithoutConfig {
    XCTAssertFalse([[LDClient sharedInstance] start:nil withUserBuilder:nil]);
}

- (void)testStartWithValidConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    LDClient *client = [LDClient sharedInstance];
    BOOL didStart = [client start:config withUserBuilder:nil];
    XCTAssertTrue(didStart);
}

- (void)testStartWithValidConfigMultipleTimes {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    XCTAssertTrue([[LDClient sharedInstance] start:config withUserBuilder:nil]);
    XCTAssertFalse([[LDClient sharedInstance] start:config withUserBuilder:nil]);
}

- (void)testBoolVariationWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    BOOL boolValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(boolValue);
}

- (void)testBoolVariationWithoutConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"boolConfigIsABool-true" configureUser:NO test:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] boolVariation:@"isABool" fallback:YES]);
    }];
}

- (void)testBoolVariationWithConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"boolConfigIsABool-true" configureUser:YES test:^(NSError *error){
        XCTAssertTrue([[LDClient sharedInstance] boolVariation:@"isABool" fallback:NO]);
    }];
}

- (void)testBoolVariationFallback {
    NSString *targetKey = @"isNotABool";
    [self verifyVariationWithMockResponseFromJSONFile:@"boolConfigIsABool-true" configureUser:YES test:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:targetKey]);
        XCTAssertTrue([[LDClient sharedInstance] boolVariation:targetKey fallback:YES]);
    }];
}

- (void)testStringVariationWithoutConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"stringConfigIsAString-someString" configureUser:NO test:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[[LDClient sharedInstance] stringVariation:@"isAString" fallback:kFallbackString] isEqualToString:kFallbackString]);
    }];
}

- (void)testStringVariationWithConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"stringConfigIsAString-someString" configureUser:YES test:^(NSError *error){
        XCTAssertTrue([[[LDClient sharedInstance] stringVariation:@"isAString" fallback:kFallbackString] isEqualToString:kTargetValueString]);
    }];
}

- (void)testStringVariationFallback {
    NSString *targetKey = @"isNotAString";
    
    [self verifyVariationWithMockResponseFromJSONFile:@"stringConfigIsAString-someString" configureUser:YES test:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:targetKey]);
        XCTAssertTrue([[[LDClient sharedInstance] stringVariation:targetKey fallback:kFallbackString] isEqualToString:kFallbackString]);
    }];
}

- (void)testNumberVariationWithoutConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"numberConfigIsANumber-2" configureUser:NO test:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[[LDClient sharedInstance] numberVariation:@"isANumber" fallback:@5] intValue] == 5);
    }];
}

- (void)testNumberVariationWithConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"numberConfigIsANumber-2" configureUser:YES test:^(NSError *error){
        XCTAssertTrue([[[LDClient sharedInstance] numberVariation:@"isANumber" fallback:@5] intValue] == 2);
    }];
}

- (void)testNumberVariationFallback {
    NSString *targetKey = @"isNotANumber";
    
    [self verifyVariationWithMockResponseFromJSONFile:@"numberConfigIsANumber-2" configureUser:YES test:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:targetKey]);
        XCTAssertTrue([[[LDClient sharedInstance] numberVariation:targetKey fallback:@5] intValue] == 5);
    }];
}

- (void)testDoubleVariationWithoutConfig {
    [self verifyVariationWithMockResponseFromJSONFile:@"doubleConfigIsADouble-Pi" configureUser:NO test:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] doubleVariation:@"isADouble" fallback:2.71828] == 2.71828);
    }];
}

- (void)testDoubleVariationWithConfig {
    NSString *targetKey = @"isADouble";
    NSString *jsonFileName = @"doubleConfigIsADouble-Pi";
    double target = [[self objectFromJsonFileNamed:jsonFileName key:targetKey] doubleValue];
    
    [self verifyVariationWithMockResponseFromJSONFile:jsonFileName configureUser:YES test:^(NSError *error){
        XCTAssertTrue([[LDClient sharedInstance] doubleVariation:targetKey fallback:2.71828] == target);
    }];
}

- (void)testDoubleVariationFallback {
    NSString *targetKey = @"isNotADouble";
    
    [self verifyVariationWithMockResponseFromJSONFile:@"doubleConfigIsADouble-Pi" configureUser:YES test:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:targetKey]);
        XCTAssertTrue([[LDClient sharedInstance] doubleVariation:targetKey fallback:2.71828] == 2.71828);
    }];
}

- (void)testArrayVariationWithoutConfig {
    NSArray *fallbackArray = @[@1, @2];
    
    [self verifyVariationWithMockResponseFromJSONFile:@"arrayConfigIsAnArray-123" configureUser:NO test:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] arrayVariation:@"isAnArray" fallback:fallbackArray] == fallbackArray);   //object equality!!
    }];
}

- (void)testArrayVariationWithConfig {
    NSString *targetKey = @"isAnArray";
    NSString *jsonFileName = @"arrayConfigIsAnArray-123";

    NSArray *fallbackArray = @[@1, @2];
    NSArray *targetArray = [self objectFromJsonFileNamed:jsonFileName key:targetKey];
    XCTAssertFalse([targetArray isEqualToArray:fallbackArray]);
    
    [self verifyVariationWithMockResponseFromJSONFile:jsonFileName configureUser:YES test:^(NSError *error){
        NSArray *arrayValue = [[LDClient sharedInstance] arrayVariation:targetKey fallback:fallbackArray];
        XCTAssertTrue([arrayValue isEqualToArray:targetArray]);
    }];
}

- (void)testArrayVariationFallback {
    NSString *targetKey = @"isNotAnArray";
    NSArray *fallbackArray = @[@1, @2];
    
    [self verifyVariationWithMockResponseFromJSONFile:@"arrayConfigIsAnArray-123" configureUser:YES test:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:targetKey]);
        NSArray *arrayValue = [[LDClient sharedInstance] arrayVariation:targetKey fallback:fallbackArray];
        XCTAssertTrue(arrayValue == fallbackArray);
    }];
}

- (void)testDictionaryVariationWithoutConfig {
    NSDictionary *fallback = @{@"key1": @"value1", @"key2": @[@1, @2]};
    [self verifyVariationWithMockResponseFromJSONFile:@"dictionaryConfigIsADictionary-3Key" configureUser:NO test:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] dictionaryVariation:@"isADictionary" fallback:fallback] == fallback);
    }];
}

- (void)testDictionaryVariationWithConfig {
    NSString *targetKey = @"isADictionary";
    NSString *jsonFileName = @"dictionaryConfigIsADictionary-3Key";

    NSDictionary *fallback = @{@"key1": @"value1", @"key2": @[@1, @2]};
    NSDictionary *target = [self objectFromJsonFileNamed:jsonFileName key:targetKey];
    XCTAssertFalse([target isEqualToDictionary:fallback]);
    
    [self verifyVariationWithMockResponseFromJSONFile:jsonFileName configureUser:YES test:^(NSError *error) {
        XCTAssertTrue([[[LDClient sharedInstance] dictionaryVariation:targetKey fallback:fallback] isEqualToDictionary:target]);
    }];
}

- (void)testDictionaryVariationFallback {
    NSString *targetKey = @"isNotADictionary";
    NSDictionary *fallback = @{@"key1": @"value1", @"key2": @[@1, @2]};
    
    [self verifyVariationWithMockResponseFromJSONFile:@"dictionaryConfigIsADictionary-3Key" configureUser:YES test:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:targetKey]);
        XCTAssertTrue([[LDClient sharedInstance] dictionaryVariation:targetKey fallback:fallback] == fallback);
    }];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testDeprecatedStartWithValidConfig {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:kTestMobileKey];
    LDClient *client = [LDClient sharedInstance];
    BOOL didStart = [client start:builder userBuilder:nil];
    XCTAssertTrue(didStart);
}

- (void)testDeprecatedStartWithValidConfigMultipleTimes {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:kTestMobileKey];
    XCTAssertTrue([[LDClient sharedInstance] start:builder userBuilder:nil]);
    XCTAssertFalse([[LDClient sharedInstance] start:builder userBuilder:nil]);
}

- (void)testDeprecatedBoolVariationWithStart {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    BOOL boolValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(boolValue);
}
#pragma clang diagnostic pop

- (void)testUserPersisted {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = @"myKey";
    userBuilder.email = @"my@email.com";
    
    [[LDClient sharedInstance] start:config withUserBuilder:userBuilder];
    BOOL toggleValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(toggleValue);
    
    LDUserBuilder *anotherUserBuilder = [[LDUserBuilder alloc] init];
    anotherUserBuilder.key = @"myKey";

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    OCMStub([self.dataManagerMock findUserWithkey:[OCMArg any]]).andReturn(user);

    [[LDClient sharedInstance] start:config withUserBuilder:anotherUserBuilder];
    user = [[LDClient sharedInstance] ldUser];
    
     XCTAssertEqual(user.email, @"my@email.com");
}

-(void)testToggleCreatesEventWithCorrectArguments {
    NSString *toggleName = @"test";
    BOOL fallbackValue = YES;
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    OCMStub([self.dataManagerMock createFeatureEvent:[OCMArg any] keyValue:[OCMArg any] defaultKeyValue:[OCMArg any]]);
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    [[LDClient sharedInstance] boolVariation:toggleName fallback:fallbackValue];
    
    OCMVerify([self.dataManagerMock createFeatureEvent:toggleName keyValue:[NSNumber numberWithBool:fallbackValue] defaultKeyValue:[NSNumber numberWithBool:fallbackValue]]);
    [self.dataManagerMock stopMocking];
}

- (void)testTrackWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] track:@"test" data:nil]);
}

- (void)testTrackWithStart {
    NSDictionary *customData = @{@"key": @"value"};
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    
    OCMStub([self.dataManagerMock createCustomEvent:[OCMArg isKindOfClass:[NSString class]]  withCustomValuesDictionary:[OCMArg isKindOfClass:[NSDictionary class]]]);
    
    XCTAssertTrue([[LDClient sharedInstance] track:@"test" data:customData]);
    
    OCMVerify([self.dataManagerMock createCustomEvent: @"test"
                           withCustomValuesDictionary: customData]);
}

- (void)testOfflineWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] offline]);
}

- (void)testOfflineWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] offline]);
}

- (void)testOnlineWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] online]);
}

- (void)testOnlineWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] online]);
}

- (void)testFlushWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] flush]);
}

- (void)testFlushWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] flush]);
}

- (void)testUpdateUserWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
}

-(void)testUpdateUserWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    
    LDClient *ldClient = [LDClient sharedInstance];
    [ldClient start:config withUserBuilder:userBuilder];
    
    XCTAssertTrue([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
}

- (void)testCurrentUserBuilderWithoutStart {
    XCTAssertNil([[LDClient sharedInstance] currentUserBuilder]);
}

-(void)testCurrentUserBuilderWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    
    LDClient *ldClient = [LDClient sharedInstance];
    [ldClient start:config withUserBuilder:userBuilder];
    
    XCTAssertNotNil([[LDClient sharedInstance] currentUserBuilder]);
}

- (void)testDelegateSet {
    LDClient *ldClient = [LDClient sharedInstance];

    ldClient.delegate = (id<ClientDelegate>)self;
    XCTAssertEqualObjects(self, ldClient.delegate);
}

- (void)testServerUnavailableCalled {
    //Mock an error flag response and set an expectation for the flag request
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil]];
    XCTestExpectation *configResponseArrived = [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:NO];

    //Configure the mock delegate to fulfill the flag request expectation
    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    delegateMock.serverUnavailableCallback = ^{
        [configResponseArrived fulfill];
    };
    
    //Configure the client with the mock delegate and start the client. The client requests flags and gets the mocked error flag response. The client should call the mock delegate's error callback.
    [self verifyDelegateCallbackWithMockDelegate:delegateMock test:^(NSError *error){
        //TODO: The issue above affects this test, which should check that the count == 1. When the issue is fixed, change this test
        XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount > 0);
    }];
}

- (void)testServerUnavailableNotCalled {
    NSString *filepath = [[NSBundle bundleForClass:[LDClientTest class]] pathForResource: @"feature_flags"
                                                                                  ofType:@"json"];
    NSData *configData = [NSData dataWithContentsOfFile:filepath];
    XCTAssertTrue([configData length] > 0);
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithData: configData statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    XCTestExpectation *configResponseArrived = [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:NO];

    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    delegateMock.userDidUpdateCallback = ^{
        [configResponseArrived fulfill];
    };
    
    [self verifyDelegateCallbackWithMockDelegate:delegateMock test:^(NSError *error){
        XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount == 0);
        XCTAssertTrue(delegateMock.userDidUpdateCallCount == 1);
        XCTAssertTrue(delegateMock.userUnchangedCallCount == 0);
    }];
}

- (void)testUserUnchangedCalled {
    NSString *filepath = [[NSBundle bundleForClass:[LDClientTest class]] pathForResource: @"feature_flags"
                                                                                  ofType:@"json"];
    NSData *configData = [NSData dataWithContentsOfFile:filepath];
    XCTAssertTrue([configData length] > 0);
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithData: configData statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    XCTestExpectation *configResponseArrived = [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:NO];
    
    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    delegateMock.userUnchangedCallback = ^{
        [configResponseArrived fulfill];
    };
    
    NSString *userKey = [[NSUUID UUID] UUIDString];
    NSDictionary *jsonConfigDictionary = [NSJSONSerialization JSONObjectWithData:configData options:0 error:nil];
    LDFlagConfigModel *currentConfig = [[LDFlagConfigModel alloc] initWithDictionary:jsonConfigDictionary];
    LDUserModel *currentUser = [[LDUserModel alloc] init];
    currentUser.config = currentConfig;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *originalDictionary = [userDefaults objectForKey:kUserDictionaryStorageKey];
    if (!originalDictionary) { originalDictionary = [NSDictionary dictionary]; }
    NSMutableDictionary *encodedDictionary = [originalDictionary mutableCopy];
    [encodedDictionary setObject:[NSKeyedArchiver archivedDataWithRootObject:currentUser] forKey:userKey];
    [userDefaults setObject:encodedDictionary forKey:kUserDictionaryStorageKey];

    [self verifyDelegateCallbackWithMockDelegate:delegateMock userKey:userKey test:^(NSError *error){
        // TODO: A previous test's "serverConnectionUnavailable" delegate callback is leaking.
        // (verified by renaming this test to run early in the test process, since tests are
        // run in alphabetical order within a test suite/file). Until that is fixed, we cannot
        // guarantee that serverConnectionUnavailable has not been called.
        //XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount == 0);
        XCTAssertTrue(delegateMock.userDidUpdateCallCount == 0);
        XCTAssertTrue(delegateMock.userUnchangedCallCount == 1);
    }];
    
    [userDefaults setObject:originalDictionary forKey:kUserDictionaryStorageKey];
}

#pragma mark - Helpers
- (void)verifyVariationWithMockResponseFromJSONFile:(NSString*)jsonFileName configureUser:(BOOL)configureUser test:(void(^)(NSError * __nullable error))testBlock {
    LDUserBuilder *userBuilder = [LDUserBuilder userBuilderWithKey:[[NSUUID UUID] UUIDString]];
    LDConfig *clientConfig = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    self.configureUser = configureUser;
    
    NSString *filepath = [[NSBundle bundleForClass:[LDClientTest class]] pathForResource: configureUser ? jsonFileName : @"emptyConfig"
                                                                                  ofType:@"json"];
    NSData *configData = [NSData dataWithContentsOfFile:filepath];
    XCTAssertTrue([configData length] > 0);
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithData: configData statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserUpdatedNotification:) name:kLDUserUpdatedNotification object:nil];
    self.userConfigUpdatedNotificationExpectation = [self expectationForNotification:kLDUserUpdatedNotification object:self handler:nil];
    
    BOOL clientStarted = [[LDClient sharedInstance] start:clientConfig withUserBuilder:userBuilder];
    XCTAssertTrue(clientStarted);
    [[LDClientManager sharedInstance] syncWithServerForConfig];
    [self waitForExpectationsWithTimeout:10 handler:testBlock];
}

- (NSString*)stubNameForTestName:(const char *)testName stubName:(NSString*)stubName {
    return [NSString stringWithFormat:@"%s.%@.%@", testName, NSStringFromClass([self class]), stubName];
}

- (XCTestExpectation*)stubResponse:(OHHTTPStubsResponse*)response forHost:(NSString*)host fulfillsExpectation:(BOOL)fulfillsExpectation {
    [OHHTTPStubs removeAllStubs];
    XCTAssert([OHHTTPStubs allStubs].count == 0);
    
    XCTestExpectation *configResponseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        if (fulfillsExpectation) {
            [configResponseArrived fulfill];
        }
        return response;
    }];
    XCTAssertTrue([[OHHTTPStubs allStubs] count] == 1);
    return configResponseArrived;
}

- (void)verifyDelegateCallbackWithMockDelegate:(MockLDClientDelegate*)mockDelegate test:(void (^)(NSError * __nullable error))testBlock {
    [self verifyDelegateCallbackWithMockDelegate:mockDelegate userKey:nil test:testBlock];
}

- (void)verifyDelegateCallbackWithMockDelegate:(MockLDClientDelegate*)mockDelegate userKey:(NSString *)userKey test:(void (^)(NSError * __nullable error))testBlock {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    
    LDUserBuilder *user = [[LDUserBuilder alloc] init];
    user.key = userKey ?: [[NSUUID UUID] UUIDString];
    
    [[LDClient sharedInstance] setDelegate:mockDelegate];
    [[LDClient sharedInstance] start:config withUserBuilder:user];
    [[LDClientManager sharedInstance] syncWithServerForConfig];
    
    [self waitForExpectationsWithTimeout:10 handler:testBlock];
}

- (void)handleUserUpdatedNotification:(NSNotification*)notification {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:NSSelectorFromString([NSString stringWithCString:__func__ encoding:NSUTF8StringEncoding]) withObject:notification waitUntilDone:YES];
        return;
    }
    if (self.configureUser == NO) {
        [LDClient sharedInstance].ldUser.config = nil;
    }
    [self.userConfigUpdatedNotificationExpectation fulfill];
}

- (id)objectFromJsonFileNamed:(NSString*)jsonFileName key:(NSString*)key {
    NSString *filepath = [[NSBundle bundleForClass:[LDClientTest class]] pathForResource: jsonFileName
                                                                                  ofType:@"json"];
    NSData *configData = [NSData dataWithContentsOfFile:filepath];
    NSError *error;
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:configData options:0 error:&error];
    return jsonDictionary[key];
}
@end

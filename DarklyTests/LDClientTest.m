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

#import <OCMock.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

typedef void(^MockLDClientDelegateCallbackBlock)();

@interface MockLDClientDelegate : NSObject <ClientDelegate>
@property (nonatomic, assign) int userDidUpdateCallCount;
@property (nonatomic, assign) int serverConnectionUnavailableCallCount;
@property (nonatomic, strong) MockLDClientDelegateCallbackBlock userDidUpdateCallback;
@property (nonatomic, strong) MockLDClientDelegateCallbackBlock serverUnavailableCallback;
@end

@implementation MockLDClientDelegate
-(instancetype)init {
    self = [super init];
    self.serverConnectionUnavailableCallCount = 0;
    
    return self;
}

-(void)userDidUpdate {
    self.userDidUpdateCallCount = [self processCallbackWithCount:self.userDidUpdateCallCount block:self.userDidUpdateCallback];
}

-(void)serverConnectionUnavailable {
    self.serverConnectionUnavailableCallCount = [self processCallbackWithCount:self.serverConnectionUnavailableCallCount block:self.serverUnavailableCallback];
}

-(int)processCallbackWithCount:(int)callbackCount block:(MockLDClientDelegateCallbackBlock)callbackBlock {
    callbackCount += 1;
    if (!callbackBlock) { return callbackCount; }
    callbackBlock();
    return callbackCount;
}
@end

@interface LDClientTest : DarklyXCTestCase <ClientDelegate>
@property (nonatomic, copy) NSString *testMobileKey;
@property (nonatomic, strong) XCTestExpectation *userConfigUpdatedNotificationExpectation;
@property (nonatomic, strong) LDUserBuilder *userBuilder;
@property (nonatomic, strong) LDConfig *clientConfig;
@property (nonatomic, assign) BOOL configureUser;
@property (nonatomic, copy) NSString *targetKey;
@end

NSString *const kFallbackString = @"fallbackString";
NSString *const kTargetValueString = @"someString";

@implementation LDClientTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.testMobileKey = @"testMobileKey";
}

- (void)tearDown {
    [[LDClient sharedInstance] stopClient];
    self.testMobileKey = nil;
    [OHHTTPStubs removeAllStubs];
    self.userConfigUpdatedNotificationExpectation = nil;
    self.userBuilder = nil;
    self.clientConfig = nil;
    self.configureUser = NO;
    self.targetKey = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    LDClient *client = [LDClient sharedInstance];
    BOOL didStart = [client start:config withUserBuilder:nil];
    XCTAssertTrue(didStart);
}

- (void)testStartWithValidConfigMultipleTimes {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    XCTAssertTrue([[LDClient sharedInstance] start:config withUserBuilder:nil]);
    XCTAssertFalse([[LDClient sharedInstance] start:config withUserBuilder:nil]);
}

- (void)testBoolVariationWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    BOOL boolValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(boolValue);
}

- (void)testBoolVariationWithoutConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"boolConfigIsABool-true" configureUser:NO targetKey:@"isABool"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] boolVariation:self.targetKey fallback:YES]);
    }];
}

- (void)testBoolVariationWithConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"boolConfigIsABool-true" configureUser:YES targetKey:@"isABool"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertTrue([[LDClient sharedInstance] boolVariation:self.targetKey fallback:NO]);
    }];
}

- (void)testBoolVariationFallback {
    [self variationSetupForTestName:__func__ jsonFileName:@"boolConfigIsABool-true" configureUser:YES targetKey:@"isNotABool"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:self.targetKey]);
        XCTAssertTrue([[LDClient sharedInstance] boolVariation:self.targetKey fallback:YES]);
    }];
}

- (void)testStringVariationWithoutConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"stringConfigIsAString-someString" configureUser:NO targetKey:@"isAString"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[[LDClient sharedInstance] stringVariation:self.targetKey fallback:kFallbackString] isEqualToString:kFallbackString]);
    }];
}

- (void)testStringVariationWithConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"stringConfigIsAString-someString" configureUser:YES targetKey:@"isAString"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertTrue([[[LDClient sharedInstance] stringVariation:self.targetKey fallback:kFallbackString] isEqualToString:kTargetValueString]);
    }];
}

- (void)testStringVariationFallback {
    [self variationSetupForTestName:__func__ jsonFileName:@"stringConfigIsAString-someString" configureUser:YES targetKey:@"isNotAString"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:self.targetKey]);
        XCTAssertTrue([[[LDClient sharedInstance] stringVariation:self.targetKey fallback:kFallbackString] isEqualToString:kFallbackString]);
    }];
}

- (void)testNumberVariationWithoutConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"numberConfigIsANumber-2" configureUser:NO targetKey:@"isANumber"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[[LDClient sharedInstance] numberVariation:self.targetKey fallback:@5] intValue] == 5);
    }];
}

- (void)testNumberVariationWithConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"numberConfigIsANumber-2" configureUser:YES targetKey:@"isANumber"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertTrue([[[LDClient sharedInstance] numberVariation:self.targetKey fallback:@5] intValue] == 2);
    }];
}

- (void)testNumberVariationFallback {
    [self variationSetupForTestName:__func__ jsonFileName:@"numberConfigIsANumber-2" configureUser:YES targetKey:@"isNotANumber"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:self.targetKey]);
        XCTAssertTrue([[[LDClient sharedInstance] numberVariation:self.targetKey fallback:@5] intValue] == 5);
    }];
}

- (void)testDoubleVariationWithoutConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"doubleConfigIsADouble-Pi" configureUser:NO targetKey:@"isADouble"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] doubleVariation:self.targetKey fallback:2.71828] == 2.71828);
    }];
}

- (void)testDoubleVariationWithConfig {
    NSString *jsonFileName = @"doubleConfigIsADouble-Pi";
    [self variationSetupForTestName:__func__ jsonFileName:jsonFileName configureUser:YES targetKey:@"isADouble"];
    double target = [[self objectFromJsonFileNamed:jsonFileName key:self.targetKey] doubleValue];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertTrue([[LDClient sharedInstance] doubleVariation:self.targetKey fallback:2.71828] == target);
    }];
}

- (void)testDoubleVariationFallback {
    NSString *jsonFileName = @"doubleConfigIsADouble-Pi";
    [self variationSetupForTestName:__func__ jsonFileName:jsonFileName configureUser:YES targetKey:@"isNotADouble"];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:self.targetKey]);
        XCTAssertTrue([[LDClient sharedInstance] doubleVariation:self.targetKey fallback:2.71828] == 2.71828);
    }];
}

- (void)testArrayVariationWithoutConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"arrayConfigIsAnArray-123" configureUser:NO targetKey:@"isAnArray"];
    NSArray *fallbackArray = @[@1, @2];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] arrayVariation:self.targetKey fallback:fallbackArray] == fallbackArray);   //object equality!!
    }];
}

- (void)testArrayVariationWithConfig {
    NSString *jsonFileName = @"arrayConfigIsAnArray-123";
    [self variationSetupForTestName:__func__ jsonFileName:jsonFileName configureUser:YES targetKey:@"isAnArray"];
    NSArray *fallbackArray = @[@1, @2];
    NSArray *targetArray = [self objectFromJsonFileNamed:jsonFileName key:self.targetKey];
    XCTAssertFalse([targetArray isEqualToArray:fallbackArray]);
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        NSArray *arrayValue = [[LDClient sharedInstance] arrayVariation:self.targetKey fallback:fallbackArray];
        XCTAssertTrue([arrayValue isEqualToArray:targetArray]);
    }];
}

- (void)testArrayVariationFallback {
    [self variationSetupForTestName:__func__ jsonFileName:@"arrayConfigIsAnArray-123" configureUser:YES targetKey:@"isNotAnArray"];
    NSArray *fallbackArray = @[@1, @2];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:self.targetKey]);
        NSArray *arrayValue = [[LDClient sharedInstance] arrayVariation:self.targetKey fallback:fallbackArray];
        XCTAssertTrue(arrayValue == fallbackArray);
    }];
}

- (void)testDictionaryVariationWithoutConfig {
    [self variationSetupForTestName:__func__ jsonFileName:@"dictionaryConfigIsADictionary-3Key" configureUser:NO targetKey:@"isADictionary"];
    NSDictionary *fallback = @{@"key1": @"value1", @"key2": @[@1, @2]};
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertNil([LDClient sharedInstance].ldUser.config);
        XCTAssertTrue([[LDClient sharedInstance] dictionaryVariation:self.targetKey fallback:fallback] == fallback);
    }];
}

- (void)testDictionaryVariationWithConfig {
    NSString *jsonFileName = @"dictionaryConfigIsADictionary-3Key";
    [self variationSetupForTestName:__func__ jsonFileName:jsonFileName configureUser:YES targetKey:@"isADictionary"];
    NSDictionary *fallback = @{@"key1": @"value1", @"key2": @[@1, @2]};
    NSDictionary *target = [self objectFromJsonFileNamed:jsonFileName key:self.targetKey];
    XCTAssertFalse([target isEqualToDictionary:fallback]);
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertTrue([[[LDClient sharedInstance] dictionaryVariation:self.targetKey fallback:fallback] isEqualToDictionary:target]);
    }];
}

- (void)testDictionaryVariationFallback {
    [self variationSetupForTestName:__func__ jsonFileName:@"dictionaryConfigIsADictionary-3Key" configureUser:YES targetKey:@"isNotADictionary"];
    NSDictionary *fallback = @{@"key1": @"value1", @"key2": @[@1, @2]};
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        XCTAssertFalse([[[[LDClient sharedInstance] ldUser].config.featuresJsonDictionary allKeys] containsObject:self.targetKey]);
        XCTAssertTrue([[LDClient sharedInstance] dictionaryVariation:self.targetKey fallback:fallback] == fallback);
    }];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testDeprecatedStartWithValidConfig {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:self.testMobileKey];
    LDClient *client = [LDClient sharedInstance];
    BOOL didStart = [client start:builder userBuilder:nil];
    XCTAssertTrue(didStart);
}

- (void)testDeprecatedStartWithValidConfigMultipleTimes {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:self.testMobileKey];
    XCTAssertTrue([[LDClient sharedInstance] start:builder userBuilder:nil]);
    XCTAssertFalse([[LDClient sharedInstance] start:builder userBuilder:nil]);
}

- (void)testDeprecatedBoolVariationWithStart {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:self.testMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    BOOL boolValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(boolValue);
}
#pragma clang diagnostic pop

- (void)testUserPersisted {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    
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
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
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
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
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
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] offline]);
}

- (void)testOnlineWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] online]);
}

- (void)testOnlineWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] online]);
}

- (void)testFlushWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] flush]);
}

- (void)testFlushWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] flush]);
}

- (void)testUpdateUserWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
}

-(void)testUpdateUserWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    
    LDClient *ldClient = [LDClient sharedInstance];
    [ldClient start:config withUserBuilder:userBuilder];
    
    XCTAssertTrue([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
}

- (void)testCurrentUserBuilderWithoutStart {
    XCTAssertNil([[LDClient sharedInstance] currentUserBuilder]);
}

-(void)testCurrentUserBuilderWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
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
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithError:[NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:nil]];
    XCTestExpectation *configResponseArrived = [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:NO testName:__func__];

    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    //NOTE: There is an issue with the LDClient that's causing the error processing code to be called multiple times. This makes the test pass.
    //An issue has been raised to resolve multiple calls: https://github.com/launchdarkly/ios-client-private/issues/42
    //TODO: Once the issue has been cleared, this code that limits the callback execution should be removed
    __block int callbackBlockExecutionCount = 0;
    delegateMock.serverUnavailableCallback = ^{
        callbackBlockExecutionCount += 1;
        if (callbackBlockExecutionCount > 1) { return; }
        [configResponseArrived fulfill];
    };
    
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    
    LDUserBuilder *user = [[LDUserBuilder alloc] init];
    user.key = [[NSUUID UUID] UUIDString];

    [[LDClient sharedInstance] setDelegate:delegateMock];
    [[LDClient sharedInstance] start:config withUserBuilder:user];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount > 0);
    }];
}

- (void)testServerUnavailableNotCalled {
    NSString *filepath = [[NSBundle bundleForClass:[LDClientTest class]] pathForResource: @"feature_flags"
                                                                                  ofType:@"json"];
    NSData *configData = [NSData dataWithContentsOfFile:filepath];
    XCTAssertTrue([configData length] > 0);
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithData: configData statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    XCTestExpectation *configResponseArrived = [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:NO testName:__func__];

    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    delegateMock.userDidUpdateCallback = ^{
        [configResponseArrived fulfill];
    };
    
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    
    LDUserBuilder *user = [[LDUserBuilder alloc] init];
    user.key = [[NSUUID UUID] UUIDString];
    
    [[LDClient sharedInstance] setDelegate:delegateMock];
    [[LDClient sharedInstance] start:config withUserBuilder:user];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount == 0);
        XCTAssertTrue(delegateMock.userDidUpdateCallCount > 0);
    }];
}

#pragma mark - Helpers
- (void)variationSetupForTestName:(const char *)testName jsonFileName:(NSString*)jsonFileName configureUser:(BOOL)configureUser targetKey:(NSString*)targetKey {
    self.userBuilder = [LDUserBuilder userBuilderWithKey:[[NSUUID UUID] UUIDString]];
    self.clientConfig = [[LDConfig alloc] initWithMobileKey:self.testMobileKey];
    self.targetKey = targetKey;
    self.configureUser = configureUser;
    
    NSString *filepath = [[NSBundle bundleForClass:[LDClientTest class]] pathForResource: configureUser ? jsonFileName : @"emptyConfig"
                                                                                  ofType:@"json"];
    NSData *configData = [NSData dataWithContentsOfFile:filepath];
    XCTAssertTrue([configData length] > 0);
    OHHTTPStubsResponse *flagResponse = [OHHTTPStubsResponse responseWithData: configData statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    [self stubResponse:flagResponse forHost:@"app.launchdarkly.com" fulfillsExpectation:YES testName:testName];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUserUpdatedNotification:) name:kLDUserUpdatedNotification object:nil];
    self.userConfigUpdatedNotificationExpectation = [self expectationForNotification:kLDUserUpdatedNotification object:self handler:nil];
    
    BOOL clientStarted = [[LDClient sharedInstance] start:self.clientConfig withUserBuilder:self.userBuilder];
    XCTAssertTrue(clientStarted);
}

- (NSString*)stubNameForTestName:(const char *)testName stubName:(NSString*)stubName {
    return [NSString stringWithFormat:@"%s.%@.%@", testName, NSStringFromClass([self class]), stubName];
}

- (XCTestExpectation*)stubResponse:(OHHTTPStubsResponse*)response forHost:(NSString*)host fulfillsExpectation:(BOOL)fulfillsExpectation testName:(const char *)testName {
    NSString *stubName = [self stubNameForTestName:testName stubName:@"flagResponseStub"];
    XCTestExpectation *configResponseArrived = [self expectationWithDescription:[NSString stringWithFormat:@"%s - response of async request has arrived", testName]];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        if (fulfillsExpectation) {
            [configResponseArrived fulfill];
        }
        return response;
    }].name = stubName;
    NSArray<id<OHHTTPStubsDescriptor>> *matchingStubs = [[OHHTTPStubs allStubs] filteredArrayUsingPredicate: [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        id<OHHTTPStubsDescriptor> evaluatedStub = (id<OHHTTPStubsDescriptor>)evaluatedObject;
        return [evaluatedStub.name isEqualToString:stubName];
    }]];
    XCTAssertTrue([matchingStubs count] == 1);
    return configResponseArrived;
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

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDClient.h"
#import "LDDataManager.h"
#import "LDUserModel.h"
#import "LDUserModel+Testable.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigTracker.h"
#import "LDUserBuilder.h"
#import "LDPollingManager.h"
#import "LDUserBuilder+Testable.h"
#import "LDClient+Testable.h"
#import "NSJSONSerialization+Testable.h"
#import "LDThrottler.h"
#import "LDFlagConfigValue+Testable.h"

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
@property (nonatomic, strong) id clientManagerMock;
@property (nonatomic, strong) id dataManagerMock;
@property (nonatomic, strong) id requestManagerMock;
@property (nonatomic, strong) id throttlerMock;
@property (nonatomic, strong) id userBuilderMock;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) LDConfig *config;
@end

NSString *const kFallbackString = @"fallbackString";
NSString *const kTargetValueString = @"someString";
NSString *const kTestMobileKey = @"testMobileKey";

@implementation LDClientTest

- (void)setUp {
    [super setUp];

    id mockClientManager = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([mockClientManager sharedInstance])).andReturn(mockClientManager);
    self.clientManagerMock = mockClientManager;

    id mockDataManager = OCMClassMock([LDDataManager class]);
    OCMStub(ClassMethod([mockDataManager sharedManager])).andReturn(mockDataManager);
    self.dataManagerMock = mockDataManager;

    id mockRequestManager = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([mockRequestManager sharedInstance])).andReturn(mockRequestManager);
    self.requestManagerMock = mockRequestManager;

    self.throttlerMock = OCMClassMock([LDThrottler class]);
    OCMStub([self.throttlerMock runThrottled:[OCMArg invokeBlock]]);
    [LDClient sharedInstance].throttler = self.throttlerMock;


    self.user = [LDUserModel stubWithKey:nil];

    self.userBuilderMock = OCMClassMock([LDUserBuilder class]);
    OCMStub([self.userBuilderMock build]).andReturn(self.user);

    self.config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
}

- (void)tearDown {
    [[LDClient sharedInstance] stopClient];
    [LDClient sharedInstance].delegate = nil;
    [OHHTTPStubs removeAllStubs];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.user = nil;
    self.config = nil;
    [self.clientManagerMock stopMocking];
    self.clientManagerMock = nil;
    [self.dataManagerMock stopMocking];
    self.dataManagerMock = nil;
    [self.requestManagerMock stopMocking];
    self.requestManagerMock = nil;
    [self.throttlerMock stopMocking];
    self.throttlerMock = nil;
    [self.userBuilderMock stopMocking];
    self.userBuilderMock = nil;

    self.userConfigUpdatedNotificationExpectation = nil;
    [super tearDown];
}

- (void)testSharedInstance {
    LDClient *first = [LDClient sharedInstance];
    LDClient *second = [LDClient sharedInstance];
    XCTAssertEqual(first, second);
}

- (void)testStartWithoutConfig {
    [[self.dataManagerMock reject] createIdentifyEventWithUser:[OCMArg any] config:[OCMArg any]];
    XCTAssertFalse([[LDClient sharedInstance] start:nil withUserBuilder:nil]);
    [self.dataManagerMock verify];
}

- (void)testStartWithValidConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = [[NSUUID UUID] UUIDString];
    [[self.dataManagerMock expect] createIdentifyEventWithUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        return [((LDUserModel*)obj).key isEqualToString:userBuilder.key];
    }] config:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDConfig class]]) { return NO; }
        return [((LDConfig*)obj).mobileKey isEqualToString:config.mobileKey];
    }]];

    BOOL didStart = [[LDClient sharedInstance] start:config withUserBuilder:userBuilder];
    XCTAssertTrue(didStart);
    [self.dataManagerMock verify];
}

- (void)testStartWithValidConfigMultipleTimes {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = [[NSUUID UUID] UUIDString];
    __block NSInteger createIdentifyEventCallCount = 0;
    [[self.dataManagerMock expect] createIdentifyEventWithUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (createIdentifyEventCallCount > 0) { return NO; }    //Make sure the client only records one identify event
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        if (![((LDUserModel*)obj).key isEqualToString:userBuilder.key]) { return NO; }
        createIdentifyEventCallCount += 1;
        return [((LDUserModel*)obj).key isEqualToString:userBuilder.key];
    }] config:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDConfig class]]) { return NO; }
        return [((LDConfig*)obj).mobileKey isEqualToString:config.mobileKey];
    }]];
    XCTAssertTrue([[LDClient sharedInstance] start:config withUserBuilder:userBuilder]);
    XCTAssertFalse([[LDClient sharedInstance] start:config withUserBuilder:userBuilder]);

    [self.dataManagerMock verify];
}

#pragma mark - Variations
#pragma mark Bool Variation
- (void)testBoolVariation_knownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"isABool";
    id defaultFlagValue = @(NO);
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"boolConfigIsABool-true"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    id targetFlagValue = flagConfigValue.value;
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:targetFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    BOOL flagValue = [[LDClient sharedInstance] boolVariation:flagKey fallback:[defaultFlagValue boolValue]];

    XCTAssertEqual(flagValue, [targetFlagValue boolValue]);
    [self.dataManagerMock verify];
}

- (void)testBoolVariation_knownFlag_nullValue {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = kLDFlagKeyIsABool;
    id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"boolConfigIsABool-false"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    flagConfigValue.value = [NSNull null];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    BOOL flagValue = [[LDClient sharedInstance] boolVariation:flagKey fallback:[defaultFlagValue boolValue]];

    XCTAssertEqualObjects(@(flagValue), defaultFlagValue);
    [self.dataManagerMock verify];
}

- (void)testBoolVariation_unknownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"dummy-flag-key";
    id defaultFlagValue = @(YES);
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"boolConfigIsABool-false"];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey reportedFlagValue:defaultFlagValue flagConfigValue:nil defaultFlagValue:defaultFlagValue user:self.user config:self.config];

    BOOL flagValue = [[LDClient sharedInstance] boolVariation:flagKey fallback:[defaultFlagValue boolValue]];

    XCTAssertEqual(flagValue, [targetFlagValue boolValue]);
    [self.dataManagerMock verify];
}

- (void)testBoolVariation_knownFlag_withoutStart {
    NSString *flagKey = @"isABool";
    id defaultFlagValue = @(YES);
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"boolConfigIsABool-false"];
    [[self.dataManagerMock reject] createFlagEvaluationEventsWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:self.user config:self.config];

    BOOL flagValue = [[LDClient sharedInstance] boolVariation:flagKey fallback:[defaultFlagValue boolValue]];

    XCTAssertEqual(flagValue, [targetFlagValue boolValue]);
    [self.dataManagerMock verify];
}

#pragma mark Number Variation
- (void)testNumberVariation_knownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"isANumber";
    id defaultFlagValue = @5;
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"numberConfigIsANumber-2"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    id targetFlagValue = flagConfigValue.value;
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:targetFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSNumber *flagValue = [[LDClient sharedInstance] numberVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testNumberVariation_knownFlag_nullValue {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = kLDFlagKeyIsANumber;
    id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"numberConfigIsANumber-2"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    flagConfigValue.value = [NSNull null];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSNumber *flagValue = [[LDClient sharedInstance] numberVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, defaultFlagValue);
    [self.dataManagerMock verify];
}

- (void)testNumberVariation_unknownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"dummy-flag-key";
    id defaultFlagValue = @5;
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"numberConfigIsANumber-2"];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSNumber *flagValue = [[LDClient sharedInstance] numberVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testNumberVariation_knownFlag_withoutStart {
    NSString *flagKey = @"isANumber";
    id defaultFlagValue = @5;
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"numberConfigIsANumber-2"];
    [[self.dataManagerMock reject] createFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:self.user
                                                                  config:self.config];

    NSNumber *flagValue = [[LDClient sharedInstance] numberVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

#pragma mark Double Variation
- (void)testDoubleVariation_knownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"isADouble";
    id defaultFlagValue = @(2.71828);
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"doubleConfigIsADouble-Pi"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    id targetFlagValue = flagConfigValue.value;
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:targetFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    double flagValue = [[LDClient sharedInstance] doubleVariation:flagKey fallback:[defaultFlagValue doubleValue]];

    XCTAssertEqual(flagValue, [targetFlagValue doubleValue]);
    [self.dataManagerMock verify];
}

- (void)testDoubleVariation_knownFlag_nullValue {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = kLDFlagKeyIsADouble;
    id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"doubleConfigIsADouble-Pi"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    flagConfigValue.value = [NSNull null];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    double flagValue = [[LDClient sharedInstance] doubleVariation:flagKey fallback:[defaultFlagValue doubleValue]];

    XCTAssertEqualObjects(@(flagValue), defaultFlagValue);
    [self.dataManagerMock verify];
}

- (void)testDoubleVariation_unknownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"dummy-flag-key";
    id defaultFlagValue = @(2.71828);
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"doubleConfigIsADouble-Pi"];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    double flagValue = [[LDClient sharedInstance] doubleVariation:flagKey fallback:[defaultFlagValue doubleValue]];

    XCTAssertEqual(flagValue, [targetFlagValue doubleValue]);
    [self.dataManagerMock verify];
}

- (void)testDoubleVariation_knownFlag_withoutStart {
    NSString *flagKey = @"isADouble";
    id defaultFlagValue = @(2.71828);
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"doubleConfigIsADouble-Pi"];
    [[self.dataManagerMock reject] createFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:self.user
                                                                  config:self.config];

    double flagValue = [[LDClient sharedInstance] doubleVariation:flagKey fallback:[defaultFlagValue doubleValue]];

    XCTAssertEqual(flagValue, [targetFlagValue doubleValue]);
    [self.dataManagerMock verify];
}

#pragma mark String Variation
- (void)testStringVariation_knownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"isAString";
    id defaultFlagValue = kFallbackString;
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"stringConfigIsAString-someString"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    id targetFlagValue = flagConfigValue.value;
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:targetFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSString *flagValue = [[LDClient sharedInstance] stringVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testStringVariation_knownFlag_nullValue {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = kLDFlagKeyIsAString;
    id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"stringConfigIsAString-someString"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    flagConfigValue.value = [NSNull null];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSString *flagValue = [[LDClient sharedInstance] stringVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, defaultFlagValue);
    [self.dataManagerMock verify];
}

- (void)testStringVariation_unknownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"dummy-flag-key";
    id defaultFlagValue = kFallbackString;
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"stringConfigIsAString-someString"];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSString *flagValue = [[LDClient sharedInstance] stringVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testStringVariation_knownFlag_withoutStart {
    NSString *flagKey = @"isAString";
    id defaultFlagValue = kFallbackString;
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"stringConfigIsAString-someString"];
    [[self.dataManagerMock reject] createFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:self.user
                                                                  config:self.config];

    NSString *flagValue = [[LDClient sharedInstance] stringVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

#pragma mark Array Variation
- (void)testArrayVariation_knownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"isAnArray";
    id defaultFlagValue = @[@1, @2];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"arrayConfigIsAnArray-123"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    id targetFlagValue = flagConfigValue.value;
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:targetFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSArray *flagValue = [[LDClient sharedInstance] arrayVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testArrayVariation_knownFlag_nullValue {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = kLDFlagKeyIsAnArray;
    id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"arrayConfigIsAnArray-123"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    flagConfigValue.value = [NSNull null];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSArray *flagValue = [[LDClient sharedInstance] arrayVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, defaultFlagValue);
    [self.dataManagerMock verify];
}

- (void)testArrayVariation_unknownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"dummy-flag-key";
    id defaultFlagValue = @[@1, @2];
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"arrayConfigIsAnArray-123"];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSArray *flagValue = [[LDClient sharedInstance] arrayVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testArrayVariation_knownFlag_withoutStart {
    NSString *flagKey = @"isAnArray";
    id defaultFlagValue = @[@1, @2];
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"arrayConfigIsAnArray-123"];
    [[self.dataManagerMock reject] createFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:self.user
                                                                  config:self.config];

    NSArray *flagValue = [[LDClient sharedInstance] arrayVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

#pragma mark Dictionary Variation
- (void)testDictionaryVariation_knownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"isADictionary";
    id defaultFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    id targetFlagValue = flagConfigValue.value;
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:targetFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSDictionary *flagValue = [[LDClient sharedInstance] dictionaryVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testDictionaryVariation_knownFlag_nullValue {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = kLDFlagKeyIsADictionary;
    id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
    LDFlagConfigModel *flagConfigModel = [self configureUserWithFlagConfigModelFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"];
    LDFlagConfigValue *flagConfigValue = [flagConfigModel flagConfigValueForFlagKey:flagKey];
    flagConfigValue.value = [NSNull null];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSDictionary *flagValue = [[LDClient sharedInstance] dictionaryVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, defaultFlagValue);
    [self.dataManagerMock verify];
}

- (void)testDictionaryVariation_unknownFlag {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilderMock];
    NSString *flagKey = @"dummy-flag-key";
    id defaultFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"];
    [[self.dataManagerMock expect] createFlagEvaluationEventsWithFlagKey:flagKey
                                                       reportedFlagValue:defaultFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultFlagValue
                                                                    user:self.user
                                                                  config:self.config];

    NSDictionary *flagValue = [[LDClient sharedInstance] dictionaryVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

- (void)testDictionaryVariation_knownFlag_withoutStart {
    NSString *flagKey = @"isADictionary";
    id defaultFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    id targetFlagValue = defaultFlagValue;
    [self configureUserWithFlagConfigModelFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"];
    [[self.dataManagerMock reject] createFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:self.user
                                                                  config:self.config];

    NSDictionary *flagValue = [[LDClient sharedInstance] dictionaryVariation:flagKey fallback:defaultFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.dataManagerMock verify];
}

#pragma mark -
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

- (void)testTrackWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] track:@"test" data:nil]);
}

- (void)testTrackWithStart {
    NSDictionary *customData = @{@"key": @"value"};
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    
    OCMStub([self.dataManagerMock createCustomEventWithKey:[OCMArg isKindOfClass:[NSString class]]  customData:[OCMArg isKindOfClass:[NSDictionary class]] user:[OCMArg any] config:[OCMArg any]]);
    
    XCTAssertTrue([[LDClient sharedInstance] track:@"test" data:customData]);
    
    OCMVerify([self.dataManagerMock createCustomEventWithKey: @"test" customData: customData user:[OCMArg isKindOfClass:[LDUserModel class]] config:config]);
}

- (void)testSetOnline_NO_beforeStart {
    [[self.clientManagerMock reject] setOnline:[OCMArg any]];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    [self.clientManagerMock verify];
    XCTAssertEqual(completionCallCount, 1);
}

- (void)testSetOnline_NO_afterStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.clientManagerMock expect] setOnline:NO];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    [self.clientManagerMock verify];
    [self.throttlerMock verify];
    XCTAssertEqual(completionCallCount, 1);
}

- (void)testSetOnline_YES_beforeStart {
    [[self.clientManagerMock reject] setOnline:[OCMArg any]];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    [self.clientManagerMock verify];
    XCTAssertEqual(completionCallCount, 1);
}

- (void)testSetOnline_YES_afterStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    [[LDClient sharedInstance] setOnline:NO];
    [[self.clientManagerMock expect] setOnline:YES];
    __block NSInteger completionCallCount = 0;
    //The throttler mock expectation is not getting fulfilled even though the LDClient does invoke it.
    //Since the throttler mock is set to execute blocks, setting the expectation on the client manager mock verifies that the client is calling the throttler

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    [self.clientManagerMock verify];
    XCTAssertEqual(completionCallCount, 1);
}

- (void)testFlushWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] flush]);
}

- (void)testFlushWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] flush]);
}

- (void)testStopClient {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];
    [[self.clientManagerMock expect] setOnline:NO];

    XCTAssertTrue([[LDClient sharedInstance] stopClient]);
    XCTAssertFalse([[LDClient sharedInstance] clientStarted]);
    OCMVerifyAll(self.clientManagerMock);
}

- (void)testUpdateUserWithoutStart {
    [[self.clientManagerMock reject] updateUser];
    [[self.dataManagerMock reject] createIdentifyEventWithUser:[OCMArg any] config:[OCMArg any]];
    XCTAssertFalse([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
    [self.clientManagerMock verify];
    [self.dataManagerMock verify];
    [self.clientManagerMock verify];
}

-(void)testUpdateUserWithStart {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[self.clientManagerMock expect] updateUser];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = [[NSUUID UUID] UUIDString];
    [[self.dataManagerMock expect] createIdentifyEventWithUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        return [((LDUserModel*)obj).key isEqualToString:userBuilder.key];
    }] config:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[LDConfig class]]) { return NO; }
        return [((LDConfig*)obj).mobileKey isEqualToString:config.mobileKey];
    }]];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];

    XCTAssertTrue([[LDClient sharedInstance] updateUser:userBuilder]);

    [self.clientManagerMock verify];
    [self.dataManagerMock verify];
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
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    LDUserBuilder *user = [[LDUserBuilder alloc] init];
    user.key = [[NSUUID UUID] UUIDString];

    //Configure the mock delegate to fulfill the flag request expectation
    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    [LDClient sharedInstance].delegate = delegateMock;

    [[LDClient sharedInstance] start:config withUserBuilder:user];

    [[NSNotificationCenter defaultCenter] postNotificationName: kLDServerConnectionUnavailableNotification object: nil];

    XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount == 1);
}

- (void)testServerUnavailableNotCalled {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    LDUserBuilder *user = [[LDUserBuilder alloc] init];
    user.key = [[NSUUID UUID] UUIDString];

    //Configure the mock delegate to fulfill the flag request expectation
    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    [LDClient sharedInstance].delegate = delegateMock;

    [[LDClient sharedInstance] start:config withUserBuilder:user];

    [[NSNotificationCenter defaultCenter] postNotificationName: kLDUserUpdatedNotification object: nil];

    XCTAssertTrue(delegateMock.serverConnectionUnavailableCallCount == 0);
    XCTAssertTrue(delegateMock.userDidUpdateCallCount == 1);
}

- (void)testOfflineOnClientUnauthorizedNotification {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];
    [[LDClient sharedInstance] start:config withUserBuilder:nil];

    [[self.clientManagerMock expect] setOnline:NO];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil];

    [self.clientManagerMock verify];
}

- (void)testUserUpdatedCalled {
    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    [LDClient sharedInstance].delegate = delegateMock;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserUpdatedNotification object:nil];

    XCTAssertTrue(delegateMock.userDidUpdateCallCount == 1);
}

- (void)testUserUnchangedCalled {
    MockLDClientDelegate *delegateMock = [[MockLDClientDelegate alloc] init];
    [LDClient sharedInstance].delegate = delegateMock;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil];

    XCTAssertTrue(delegateMock.userUnchangedCallCount == 1);
}

#pragma mark - Helpers
- (id)objectFromJsonFileNamed:(NSString*)jsonFileName key:(NSString*)key {
    NSDictionary *jsonDictionary = [NSJSONSerialization jsonObjectFromFileNamed:jsonFileName];
    return jsonDictionary[key];
}

- (id)valueFromJsonFileNamed:(NSString*)jsonFileName key:(NSString*)key {
    return [self objectFromJsonFileNamed:jsonFileName key:key][kLDFlagConfigValueKeyValue];
}

-(LDFlagConfigModel*)configureUserWithFlagConfigModelFromJsonFileNamed:(NSString*)fileName {
    LDFlagConfigModel *flagConfigModel = [LDFlagConfigModel flagConfigFromJsonFileNamed:fileName];
    [LDClient sharedInstance].ldUser.flagConfig = flagConfigModel;

    return flagConfigModel;
}

@end

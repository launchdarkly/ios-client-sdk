//
//  LDEnvironmentTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/3/18.
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import <OCMock/OCMock.h>

#import "LDEnvironment.h"
#import "LDEnvironmentController.h"
#import "LDDataManager.h"
#import "LDFlagConfigModel.h"

#import "ClientDelegateMock.h"
#import "LDUserModel+Testable.h"
#import "LDFlagConfigValue+Testable.h"
#import "NSThread+MainExecutable.h"
#import "LDConfig+Testable.h"

#pragma mark - ClientDelegateProtocolMock

@interface ClientDelegateProtocolWithoutMethodsMock : NSObject<ClientDelegate>

@end

@implementation ClientDelegateProtocolWithoutMethodsMock

@end

#pragma mark - LDEnvironment(LDEnvironmentTest)

@interface LDEnvironment(LDEnvironmentTest)
@property (nonatomic, assign) BOOL environmentStarted;
@property (nonatomic, assign) BOOL willGoOnlineAfterDelay;
@property (nonatomic, strong) LDEnvironmentController *environmentController;
@property (nonatomic, strong) LDDataManager *dataManager;
-(void)notifyDelegateOfUpdatesForFlagKeys:(NSArray<NSString*>*)updatedFlagKeys;
@end

#pragma mark - LDEnvironmentTest

@interface LDEnvironmentTest: DarklyXCTestCase
@property (nonatomic, strong) ClientDelegateMock *clientDelegateMock;
@property (nonatomic, copy) NSString *mobileKey;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) id dataManagerMock;
@property (nonatomic, strong) id environmentControllerMock;
@property (nonatomic, strong) LDEnvironment *environment;
@end

@implementation LDEnvironmentTest
static NSString *const secondaryEnvironmentMobileKey = @"LDEnvironmentTest.secondaryEnvironment.mobileKey";
static NSString *const featureFlagKey = @"LDEnvironmentTest.featureFlagKey";
static NSString *const customEventName = @"LDEnvironmentTest.Event.custom.eventName";
static NSString *const dummyFeatureFlagKey = @"LDEnvironmentTest.FeatureFlags.Keys.dummy";
static NSString *const stringFeatureFlagValue = @"test";
static NSString *const defaultStringFeatureFlagValue = @"LDEnvironmentTest.FeatureFlags.Values.default";

-(void)setUp {
    [super setUp];
    self.clientDelegateMock = [ClientDelegateMock clientDelegateMock];
    self.mobileKey = @"LDEnvironmentTest.primaryEnvironment.mobileKey";
    self.config = [[LDConfig alloc] initWithMobileKey:self.mobileKey];
    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    self.dataManagerMock = [OCMockObject niceMockForClass:[LDDataManager class]];
    [[[self.dataManagerMock stub] andReturn:self.dataManagerMock] dataManagerWithMobileKey:self.mobileKey config:self.config];
    self.environmentControllerMock = [OCMockObject niceMockForClass:[LDEnvironmentController class]];
    [[[self.environmentControllerMock stub] andReturn:self.environmentControllerMock] controllerWithMobileKey:self.mobileKey config:self.config user:[OCMArg checkWithBlock:^BOOL(id obj) {
        //Because the environment makes a copy of the user, this makes sure to serve the environmentControllerMock whenever the user passed into controllerWithMobileKey matches self.user
        return [obj isEqual:self.user ignoringAttributes:@[kUserAttributeUpdatedAt]];
    }] dataManager:self.dataManagerMock];
    self.environment = [LDEnvironment environmentForMobileKey:self.mobileKey config:self.config user:self.user];
    [[[self.dataManagerMock stub] andReturn:self.user.flagConfig] retrieveFlagConfigForUser:self.environment.user];
    self.environment.delegate = self.clientDelegateMock;
}

-(void)tearDown {
    self.clientDelegateMock = nil;
    self.dataManagerMock = nil;
    self.environmentControllerMock = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self.environment];
    [super tearDown];
}

#pragma mark - Lifecycle

-(void)testInitAndConstructor {
    XCTAssertNotNil(self.environment);
    XCTAssertEqualObjects(self.environment.mobileKey, self.config.mobileKey);
    XCTAssertEqualObjects(self.environment.config, self.config);
    XCTAssertTrue([self.environment.user isEqual:self.user ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    XCTAssertEqual(self.environment.isStarted, NO);
    XCTAssertEqual(self.environment.isOnline, NO);
    XCTAssertEqualObjects(self.environment.delegate, self.clientDelegateMock);
    XCTAssertEqualObjects(self.environment.environmentController, self.environmentControllerMock);
    XCTAssertEqualObjects(self.environment.dataManager, self.dataManagerMock);
}

-(void)testIsPrimary_mobileKeyMatchesConfigMobileKey {
    XCTAssertTrue(self.environment.isPrimary);
}

-(void)testIsPrimary_mobileKeyDiffersFromConfigMobileKey {
    self.environment = [LDEnvironment environmentForMobileKey:[NSUUID UUID].UUIDString config:self.config user:self.user];

    XCTAssertFalse(self.environment.isPrimary);
}

-(void)testEnvironmentName_primaryEnvironment {
    XCTAssertEqualObjects(self.environment.environmentName, kLDPrimaryEnvironmentName);
}

-(void)testEnvironmentName_secondaryEnvironment {
    NSDictionary *secondaryMobileKeysMock = [LDConfig secondaryMobileKeysStub];
    self.config.secondaryMobileKeys = secondaryMobileKeysMock;

    for (NSString *keyName in secondaryMobileKeysMock.allKeys) {
        NSString *mobileKey = secondaryMobileKeysMock[keyName];
        self.environment = [LDEnvironment environmentForMobileKey:mobileKey config:self.config user:self.user];

        XCTAssertEqualObjects(self.environment.environmentName, keyName);
    }
}

#pragma mark - Controls

-(void)testStart {
    self.dataManagerMock = [OCMockObject niceMockForClass:[LDDataManager class]];
    [[[self.dataManagerMock stub] andReturn:self.dataManagerMock] dataManagerWithMobileKey:self.mobileKey config:self.config];
    self.environment = [LDEnvironment environmentForMobileKey:self.mobileKey config:self.config user:self.user];
    [[self.dataManagerMock expect] convertToEnvironmentBasedCacheForUser:self.environment.user config:self.config];
    [[[self.dataManagerMock expect] andReturn:self.user.flagConfig] retrieveFlagConfigForUser:self.environment.user];
    [[self.dataManagerMock expect] saveUser:self.environment.user];
    [[self.dataManagerMock expect] recordIdentifyEventWithUser:self.environment.user];

    [self.environment start];

    XCTAssertTrue(self.environment.isStarted);
    [self.dataManagerMock verify];
}

-(void)testStart_secondaryEnvironment {
    NSString *mobileKey = [NSUUID UUID].UUIDString;
    self.dataManagerMock = [OCMockObject niceMockForClass:[LDDataManager class]];
    [[[self.dataManagerMock stub] andReturn:self.dataManagerMock] dataManagerWithMobileKey:mobileKey config:self.config];
    self.environment = [LDEnvironment environmentForMobileKey:mobileKey config:self.config user:self.user];
    [[self.dataManagerMock reject] convertToEnvironmentBasedCacheForUser:[OCMArg any] config:[OCMArg any]];
    [[self.dataManagerMock expect] retrieveFlagConfigForUser:self.environment.user];
    [[self.dataManagerMock expect] saveUser:self.environment.user];
    [[self.dataManagerMock expect] recordIdentifyEventWithUser:self.environment.user];

    [self.environment start];

    XCTAssertTrue(self.environment.isStarted);
    [self.dataManagerMock verify];
}

-(void)testStop {
    [self.environment start];
    self.environment.online = YES;
    [[self.environmentControllerMock expect] setOnline:NO];

    [self.environment stop];

    XCTAssertFalse(self.environment.isStarted);
    XCTAssertFalse(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testOnline {
    [self.environment start];
    [[self.environmentControllerMock expect] setOnline:YES];

    self.environment.online = YES;

    XCTAssertTrue(self.environment.isOnline);

    [[self.environmentControllerMock expect] setOnline:NO];

    self.environment.online = NO;

    XCTAssertFalse(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testOnline_alreadyOnline {
    [self.environment start];
    self.environment.online = YES;
    [[[self.environmentControllerMock stub] andReturnValue:@YES] isOnline];
    [[self.environmentControllerMock reject] setOnline:YES];

    self.environment.online = YES;

    XCTAssertTrue(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testOnline_alreadyOnline_controllerOffline {
    [self.environment start];
    self.environment.online = YES;
    [[[self.environmentControllerMock stub] andReturnValue:@NO] isOnline];
    [[self.environmentControllerMock expect] setOnline:YES];

    self.environment.online = YES;

    XCTAssertTrue(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testOnline_alreadyOffline {
    [self.environment start];
    [[self.environmentControllerMock reject] setOnline:NO];

    self.environment.online = NO;

    XCTAssertFalse(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testOnline_alreadyOffline_controllerOnline {
    [self.environment start];
    [[[self.environmentControllerMock stub] andReturnValue:@YES] isOnline];
    [[self.environmentControllerMock expect] setOnline:NO];

    self.environment.online = NO;

    XCTAssertFalse(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testOnline_notStarted {
    [[self.environmentControllerMock reject] setOnline:[OCMArg any]];

    self.environment.online = YES;

    XCTAssertFalse(self.environment.isOnline);
    [self.environmentControllerMock verify];
}

-(void)testFlush {
    [self.environment start];
    self.environment.online = YES;
    [[self.environmentControllerMock expect] flushEvents];

    BOOL result = [self.environment flush];

    XCTAssertTrue(result);
    [self.environmentControllerMock verify];
}

-(void)testFlush_offline {
    [self.environment start];
    [[self.environmentControllerMock reject] flushEvents];

    BOOL result = [self.environment flush];

    XCTAssertFalse(result);
    [self.environmentControllerMock verify];
}

-(void)testFlush_notStarted {
    [[self.environmentControllerMock reject] flushEvents];

    BOOL result = [self.environment flush];

    XCTAssertFalse(result);
    [self.environmentControllerMock verify];
}

#pragma mark - Feature Flags

//Bool Variation ------
-(void)testBoolVariation {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsABool];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsABool
                                                       reportedFlagValue:@(NO)
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:@(YES)
                                                                    user:self.environment.user];

    BOOL reportedValue = [self.environment boolVariation:kLDFlagKeyIsABool fallback:YES];

    XCTAssertFalse(reportedValue);
    [self.dataManagerMock verify];
}

-(void)testBoolVariation_flagMissing {
    [self.environment start];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:dummyFeatureFlagKey
                                                       reportedFlagValue:@(YES)
                                                         flagConfigValue:nil
                                                        defaultFlagValue:@(YES)
                                                                    user:self.environment.user];

    BOOL reportedValue = [self.environment boolVariation:dummyFeatureFlagKey fallback:YES];

    XCTAssertTrue(reportedValue);
    [self.dataManagerMock verify];
}

-(void)testBoolVariation_nullValue {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANull];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANull
                                                       reportedFlagValue:@(YES)
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:@(YES)
                                                                    user:self.environment.user];

    BOOL reportedValue = [self.environment boolVariation:kLDFlagKeyIsANull fallback:YES];

    XCTAssertTrue(reportedValue);
    [self.dataManagerMock verify];
}

-(void)testBoolVariation_notStarted {
    [[self.dataManagerMock reject] recordFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:[OCMArg any]];

    BOOL reportedValue = [self.environment boolVariation:dummyFeatureFlagKey fallback:YES];

    XCTAssertTrue(reportedValue);
    [self.dataManagerMock verify];
}

//Number Variation ------
-(void)testNumberVariation {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANumber];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANumber
                                                       reportedFlagValue:@(0)
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:@(7)
                                                                    user:self.environment.user];

    NSNumber *reportedValue = [self.environment numberVariation:kLDFlagKeyIsANumber fallback:@(7)];

    XCTAssertEqualObjects(reportedValue, @(0));
    [self.dataManagerMock verify];
}

-(void)testNumberVariation_flagMissing {
    [self.environment start];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:dummyFeatureFlagKey
                                                       reportedFlagValue:@(7)
                                                         flagConfigValue:nil
                                                        defaultFlagValue:@(7)
                                                                    user:self.environment.user];

    NSNumber *reportedValue = [self.environment numberVariation:dummyFeatureFlagKey fallback:@(7)];

    XCTAssertEqualObjects(reportedValue, @(7));
    [self.dataManagerMock verify];
}

-(void)testNumberVariation_nullValue {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANull];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANull
                                                       reportedFlagValue:@(7)
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:@(7)
                                                                    user:self.environment.user];

    NSNumber *reportedValue = [self.environment numberVariation:kLDFlagKeyIsANull fallback:@(7)];

    XCTAssertEqualObjects(reportedValue, @(7));
    [self.dataManagerMock verify];
}

-(void)testNumberVariation_notStarted {
    [[self.dataManagerMock reject] recordFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:[OCMArg any]];

    NSNumber *reportedValue = [self.environment numberVariation:kLDFlagKeyIsANull fallback:@(7)];

    XCTAssertEqualObjects(reportedValue, @(7));
    [self.dataManagerMock verify];
}

//Double Variation ------
-(void)testDoubleVariation {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsADouble];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsADouble
                                                       reportedFlagValue:flagConfigValue.value
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:@(2.71828)
                                                                    user:self.environment.user];

    double reportedValue = [self.environment doubleVariation:kLDFlagKeyIsADouble fallback:2.71828];

    XCTAssertEqual(reportedValue, [flagConfigValue.value doubleValue]);
    [self.dataManagerMock verify];
}

-(void)testDoubleVariation_flagMissing {
    [self.environment start];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:dummyFeatureFlagKey
                                                       reportedFlagValue:@(2.71828)
                                                         flagConfigValue:nil
                                                        defaultFlagValue:@(2.71828)
                                                                    user:self.environment.user];

    double reportedValue = [self.environment doubleVariation:dummyFeatureFlagKey fallback:2.71828];

    XCTAssertEqual(reportedValue, 2.71828);
    [self.dataManagerMock verify];
}

-(void)testDoubleVariation_nullValue {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANull];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANull
                                                       reportedFlagValue:@(2.71828)
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:@(2.71828)
                                                                    user:self.environment.user];

    double reportedValue = [self.environment doubleVariation:kLDFlagKeyIsANull fallback:2.71828];

    XCTAssertEqual(reportedValue, 2.71828);
    [self.dataManagerMock verify];
}

-(void)testDoubleVariation_notStarted {
    [[self.dataManagerMock reject] recordFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:[OCMArg any]];

    double reportedValue = [self.environment doubleVariation:kLDFlagKeyIsANull fallback:2.71828];

    XCTAssertEqual(reportedValue, 2.71828);
    [self.dataManagerMock verify];
}

//String Variation ------
-(void)testStringVariation {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsAString];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsAString
                                                       reportedFlagValue:stringFeatureFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultStringFeatureFlagValue
                                                                    user:self.environment.user];

    NSString *reportedValue = [self.environment stringVariation:kLDFlagKeyIsAString fallback:defaultStringFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, stringFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testStringVariation_flagMissing {
    [self.environment start];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:dummyFeatureFlagKey
                                                       reportedFlagValue:defaultStringFeatureFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultStringFeatureFlagValue
                                                                    user:self.environment.user];

    NSString *reportedValue = [self.environment stringVariation:dummyFeatureFlagKey fallback:defaultStringFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultStringFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testStringVariation_nullValue {
    [self.environment start];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANull];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANull
                                                       reportedFlagValue:defaultStringFeatureFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultStringFeatureFlagValue
                                                                    user:self.environment.user];

    NSString *reportedValue = [self.environment stringVariation:kLDFlagKeyIsANull fallback:defaultStringFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultStringFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testStringVariation_notStarted {
    [[self.dataManagerMock reject] recordFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:[OCMArg any]];

    NSString *reportedValue = [self.environment stringVariation:kLDFlagKeyIsANull fallback:defaultStringFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultStringFeatureFlagValue);
    [self.dataManagerMock verify];
}

//Array Variation ------
-(void)testArrayVariation {
    [self.environment start];
    NSArray *defaultArrayFeatureFlagValue = @[@(1), @(2)];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsAnArray];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsAnArray
                                                       reportedFlagValue:flagConfigValue.value
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultArrayFeatureFlagValue
                                                                    user:self.environment.user];

    NSArray *reportedValue = [self.environment arrayVariation:kLDFlagKeyIsAnArray fallback:defaultArrayFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, flagConfigValue.value);
    [self.dataManagerMock verify];
}

-(void)testArrayVariation_flagMissing {
    [self.environment start];
    NSArray *defaultArrayFeatureFlagValue = @[@(1), @(2)];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:dummyFeatureFlagKey
                                                       reportedFlagValue:defaultArrayFeatureFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultArrayFeatureFlagValue
                                                                    user:self.environment.user];

    NSArray *reportedValue = [self.environment arrayVariation:dummyFeatureFlagKey fallback:defaultArrayFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultArrayFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testArrayVariation_nullValue {
    [self.environment start];
    NSArray *defaultArrayFeatureFlagValue = @[@(1), @(2)];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANull];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANull
                                                       reportedFlagValue:defaultArrayFeatureFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultArrayFeatureFlagValue
                                                                    user:self.environment.user];

    NSArray *reportedValue = [self.environment arrayVariation:kLDFlagKeyIsANull fallback:defaultArrayFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultArrayFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testArrayVariation_notStarted {
    NSArray *defaultArrayFeatureFlagValue = @[@(1), @(2)];
    [[self.dataManagerMock reject] recordFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:[OCMArg any]];

    NSArray *reportedValue = [self.environment arrayVariation:kLDFlagKeyIsANull fallback:defaultArrayFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultArrayFeatureFlagValue);
    [self.dataManagerMock verify];
}

//Dictionary Variation ------
-(void)testDictionaryVariation {
    [self.environment start];
    NSDictionary *defaultDictionaryFeatureFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsADictionary];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsADictionary
                                                       reportedFlagValue:flagConfigValue.value
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultDictionaryFeatureFlagValue
                                                                    user:self.environment.user];

    NSDictionary *reportedValue = [self.environment dictionaryVariation:kLDFlagKeyIsADictionary fallback:defaultDictionaryFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, flagConfigValue.value);
    [self.dataManagerMock verify];
}

-(void)testDictionaryVariation_flagMissing {
    [self.environment start];
    NSDictionary *defaultDictionaryFeatureFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:dummyFeatureFlagKey
                                                       reportedFlagValue:defaultDictionaryFeatureFlagValue
                                                         flagConfigValue:nil
                                                        defaultFlagValue:defaultDictionaryFeatureFlagValue
                                                                    user:self.environment.user];

    NSDictionary *reportedValue = [self.environment dictionaryVariation:dummyFeatureFlagKey fallback:defaultDictionaryFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultDictionaryFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testDictionaryVariation_nullValue {
    [self.environment start];
    NSDictionary *defaultDictionaryFeatureFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kLDFlagKeyIsANull];
    [[self.dataManagerMock expect] recordFlagEvaluationEventsWithFlagKey:kLDFlagKeyIsANull
                                                       reportedFlagValue:defaultDictionaryFeatureFlagValue
                                                         flagConfigValue:flagConfigValue
                                                        defaultFlagValue:defaultDictionaryFeatureFlagValue
                                                                    user:self.environment.user];

    NSDictionary *reportedValue = [self.environment dictionaryVariation:kLDFlagKeyIsANull fallback:defaultDictionaryFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultDictionaryFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testDictionaryVariation_notStarted {
    NSDictionary *defaultDictionaryFeatureFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    [[self.dataManagerMock reject] recordFlagEvaluationEventsWithFlagKey:[OCMArg any]
                                                       reportedFlagValue:[OCMArg any]
                                                         flagConfigValue:[OCMArg any]
                                                        defaultFlagValue:[OCMArg any]
                                                                    user:[OCMArg any]];

    NSDictionary *reportedValue = [self.environment dictionaryVariation:kLDFlagKeyIsANull fallback:defaultDictionaryFeatureFlagValue];

    XCTAssertEqualObjects(reportedValue, defaultDictionaryFeatureFlagValue);
    [self.dataManagerMock verify];
}

-(void)testAllFlags {
    [self.environment start];

    NSDictionary *allFlags = self.environment.allFlags;

    for (NSString *flagKey in self.user.flagConfig.featuresJsonDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:flagKey];
        if (flagConfigValue.value == nil || [flagConfigValue.value isKindOfClass:[NSNull class]]) {
            XCTAssertNil(allFlags[flagKey]);
        } else {
            XCTAssertEqualObjects(allFlags[flagKey], flagConfigValue.value);
        }
    }
}

-(void)testAllFlags_notStarted {
    NSDictionary *allFlags = self.environment.allFlags;

    XCTAssertNil(allFlags);
}

#pragma mark - Event Tracking

-(void)testTrack {
    [self.environment start];
    NSDictionary *customEventData = @{@"The Answer":@(42)};
    [[self.dataManagerMock expect] recordCustomEventWithKey:customEventName customData:customEventData user:self.environment.user];

    BOOL result = [self.environment track:customEventName data:customEventData];

    XCTAssertTrue(result);
    [self.dataManagerMock verify];
}

-(void)testTrack_notStarted {
    NSDictionary *customEventData = @{@"The Answer":@(42)};
    [[self.dataManagerMock reject] recordCustomEventWithKey:[OCMArg any] customData:[OCMArg any] user:[OCMArg any]];

    BOOL result = [self.environment track:customEventName data:customEventData];

    XCTAssertFalse(result);
    [self.dataManagerMock verify];
}

#pragma mark - User

-(void)testUpdateUser {
    [self.environment start];
    self.environment.online = YES;
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    id newUserMock = [OCMockObject niceMockForClass:[LDUserModel class]];
    [[[newUserMock expect] andReturn:newUser] copy];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.environment.user];
    [[self.environmentControllerMock expect] setOnline:NO];
    [[self.dataManagerMock expect] convertToEnvironmentBasedCacheForUser:newUser config:self.config];
    [[self.dataManagerMock expect] retrieveFlagConfigForUser:newUser];
    [[self.dataManagerMock expect] recordIdentifyEventWithUser:newUser];
    [[self.dataManagerMock expect] saveUser:newUser];
    [[[self.environmentControllerMock expect] andReturn:self.environmentControllerMock] controllerWithMobileKey:self.mobileKey config:self.config user:newUser dataManager:self.dataManagerMock];
    [[self.environmentControllerMock expect] setOnline:YES];

    [self.environment updateUser:newUserMock];

    XCTAssertEqualObjects(self.environment.user, newUser);
    XCTAssertTrue(self.environment.isOnline);
    [newUserMock verify];
    [self.environmentControllerMock verify];
    [self.dataManagerMock verify];
}

-(void)testUpdateUser_secondaryEnvironment {
    //Replace the original mocks and environment with mocks and an environment configured with a different key than in config.mobileKey
    NSString *mobileKey = [NSUUID UUID].UUIDString;
    self.dataManagerMock = [OCMockObject niceMockForClass:[LDDataManager class]];
    [[[self.dataManagerMock stub] andReturn:self.dataManagerMock] dataManagerWithMobileKey:mobileKey config:self.config];
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    id newUserMock = [OCMockObject niceMockForClass:[LDUserModel class]];
    [[[newUserMock expect] andReturn:newUser] copy];
    id originalEnvironmentControllerMock = self.environmentControllerMock;  //Keep the original, which should be called to set offline prior to setting the user
    self.environmentControllerMock = [OCMockObject niceMockForClass:[LDEnvironmentController class]];
    [[[self.environmentControllerMock expect] andReturn:self.environmentControllerMock] controllerWithMobileKey:mobileKey config:self.config user:[OCMArg checkWithBlock:^BOOL(id obj) {
        //Because the environment makes a copy of the user, this makes sure to serve the environmentControllerMock whenever the user passed into controllerWithMobileKey matches self.user
        if (![obj isKindOfClass:[LDUserModel class]]) { return NO; }
        LDUserModel *user = obj;
        return [user isEqual:newUser ignoringAttributes:@[kUserAttributeUpdatedAt]];
    }] dataManager:self.dataManagerMock];
    self.environment = [LDEnvironment environmentForMobileKey:mobileKey config:self.config user:self.user];

    [self.environment start];
    self.environment.online = YES;
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.environment.user];
    [[originalEnvironmentControllerMock expect] setOnline:NO];
    [[self.dataManagerMock reject] convertToEnvironmentBasedCacheForUser:[OCMArg any] config:[OCMArg any]];
    [[self.dataManagerMock expect] retrieveFlagConfigForUser:newUser];
    [[self.dataManagerMock expect] recordIdentifyEventWithUser:newUser];
    [[self.dataManagerMock expect] saveUser:newUser];
    [[self.environmentControllerMock expect] setOnline:YES];

    [self.environment updateUser:newUserMock];

    XCTAssertEqualObjects(self.environment.user, newUser);
    XCTAssertTrue(self.environment.isOnline);
    [newUserMock verify];
    [self.environmentControllerMock verify];
    [self.dataManagerMock verify];
}

-(void)testUpdateUser_offline {
    [self.environment start];
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    id newUserMock = [OCMockObject niceMockForClass:[LDUserModel class]];
    [[[newUserMock expect] andReturn:newUser] copy];
    [[self.dataManagerMock expect] recordSummaryEventAndResetTrackerForUser:self.environment.user];
    [[self.environmentControllerMock reject] setOnline:NO];
    [[self.dataManagerMock expect] convertToEnvironmentBasedCacheForUser:newUser config:self.config];
    [[self.dataManagerMock expect] retrieveFlagConfigForUser:newUser];
    [[self.dataManagerMock expect] recordIdentifyEventWithUser:newUser];
    [[self.dataManagerMock expect] saveUser:newUser];
    [[[self.environmentControllerMock expect] andReturn:self.environmentControllerMock] controllerWithMobileKey:self.mobileKey config:self.config user:newUser dataManager:self.dataManagerMock];
    [[self.environmentControllerMock reject] setOnline:YES];

    [self.environment updateUser:newUserMock];

    XCTAssertEqualObjects(self.environment.user, newUser);
    XCTAssertFalse(self.environment.isOnline);
    [newUserMock verify];
    [self.environmentControllerMock verify];
    [self.dataManagerMock verify];
}

-(void)testUpdateUser_missingNewUser {
    LDUserModel *originalEnvironmentUser = self.environment.user;
    [self.environment start];
    self.environment.online = YES;
    [[self.dataManagerMock reject] recordSummaryEventAndResetTrackerForUser:[OCMArg any]];
    [[self.environmentControllerMock reject] setOnline:[OCMArg any]];
    [[self.dataManagerMock reject] convertToEnvironmentBasedCacheForUser:[OCMArg any] config:[OCMArg any]];
    [[self.dataManagerMock reject] retrieveFlagConfigForUser:[OCMArg any]];
    [[self.dataManagerMock reject] recordIdentifyEventWithUser:[OCMArg any]];
    [[self.environmentControllerMock reject] controllerWithMobileKey:[OCMArg any] config:[OCMArg any] user:[OCMArg any] dataManager:[OCMArg any]];

    [self.environment updateUser:nil];

    XCTAssertEqualObjects(self.environment.user, originalEnvironmentUser);
    XCTAssertTrue(self.environment.isOnline);
    [self.environmentControllerMock verify];
    [self.dataManagerMock verify];
}

-(void)testUpdateUser_notStarted {
    LDUserModel *originalEnvironmentUser = self.environment.user;
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    [[self.dataManagerMock reject] recordSummaryEventAndResetTrackerForUser:[OCMArg any]];
    [[self.environmentControllerMock reject] setOnline:[OCMArg any]];
    [[self.dataManagerMock reject] convertToEnvironmentBasedCacheForUser:[OCMArg any] config:[OCMArg any]];
    [[self.dataManagerMock reject] retrieveFlagConfigForUser:[OCMArg any]];
    [[self.dataManagerMock reject] recordIdentifyEventWithUser:[OCMArg any]];
    [[self.environmentControllerMock reject] controllerWithMobileKey:[OCMArg any] config:[OCMArg any] user:[OCMArg any] dataManager:[OCMArg any]];

    [self.environment updateUser:newUser];

    XCTAssertEqualObjects(self.environment.user, originalEnvironmentUser);
    XCTAssertFalse(self.environment.isOnline);
    [self.environmentControllerMock verify];
    [self.dataManagerMock verify];
}

#pragma mark - Notification Handling

-(void)testHandleUserUpdated {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserUpdatedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    XCTAssertEqual(self.clientDelegateMock.userDidUpdateCallCount, 1);
}

-(void)testHandleUserUpdated_delegateDoesNotRespond {
    id clientDelegateMock = [OCMockObject niceMockForClass:[ClientDelegateProtocolWithoutMethodsMock class]];
    self.environment.delegate = clientDelegateMock;
    [self.environment start];
    self.environment.online = YES;
    [[clientDelegateMock reject] userDidUpdate];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserUpdatedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    [clientDelegateMock verify];
}

-(void)testHandleUserUpdated_otherEnvironment {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserUpdatedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:secondaryEnvironmentMobileKey}];

    XCTAssertEqual(self.clientDelegateMock.userDidUpdateCallCount, 0);
}

- (void)testHandleUserUnchanged {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    XCTAssertEqual(self.clientDelegateMock.userUnchangedCallCount, 1);
}

- (void)testHandleUserUnchanged_otherEnvironment {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:secondaryEnvironmentMobileKey}];

    XCTAssertEqual(self.clientDelegateMock.userUnchangedCallCount, 0);
}

- (void)testHandleUserUnchanged_delegateDoesNotRespond {
    id clientDelegateMock = [OCMockObject niceMockForClass:[ClientDelegateProtocolWithoutMethodsMock class]];
    self.environment.delegate = clientDelegateMock;
    [self.environment start];
    self.environment.online = YES;
    [[clientDelegateMock reject] userUnchanged];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDUserNoChangeNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    [clientDelegateMock verify];
}

- (void)testHandleFeatureFlagsChanged {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDFeatureFlagsChangedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey,
                                                                                                                        kLDNotificationUserInfoKeyFlagKeys:@[featureFlagKey]}];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 1);
}

- (void)testHandleFeatureFlagsChanged_otherEnvironment {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDFeatureFlagsChangedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:secondaryEnvironmentMobileKey,
                                                                                                                        kLDNotificationUserInfoKeyFlagKeys:@[featureFlagKey]}];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
}

- (void)testHandleFeatureFlagsChanged_missingFlagKey {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDFeatureFlagsChangedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
}

- (void)testHandleFeatureFlagsChanged_delegateDoesNotRespond {
    id clientDelegateMock = [OCMockObject niceMockForClass:[ClientDelegateProtocolWithoutMethodsMock class]];
    self.environment.delegate = clientDelegateMock;
    [self.environment start];
    self.environment.online = YES;
    [[clientDelegateMock reject] featureFlagDidUpdate:[OCMArg any]];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDFeatureFlagsChangedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey,
                                                                                                                        kLDNotificationUserInfoKeyFlagKeys:@[featureFlagKey]}];
    [clientDelegateMock verify];
}

-(void)testNotifyDelegateOfUpdates {
    [self.environment start];
    self.environment.online = YES;
    NSMutableArray<NSString*> *notifiedFlagKeys = [NSMutableArray arrayWithCapacity:[LDFlagConfigValue flagKeys].count];
    XCTestExpectation *delegateNotifiedExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.delegateNotifiedExpectation",
                                                                                       NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];

    self.clientDelegateMock.featureFlagDidUpdateCallback = ^(NSString *flagKey) {
        [notifiedFlagKeys addObject:flagKey];
        if ([[NSSet setWithArray:notifiedFlagKeys] isEqualToSet:[NSSet setWithArray:[LDFlagConfigValue flagKeys]]]) {
            [delegateNotifiedExpectation fulfill];
        }
    };

    [self.environment notifyDelegateOfUpdatesForFlagKeys:[LDFlagConfigValue flagKeys]];
    [self waitForExpectations:@[delegateNotifiedExpectation] timeout:1.0];
}

-(void)testNotifyDelegateOfUpdates_notStarted {
    self.environment.online = YES;
    id threadMock = [OCMockObject niceMockForClass:[NSThread class]];
    [[threadMock reject] performOnMainThread:[OCMArg any] waitUntilDone:[OCMArg any]];

    [self.environment notifyDelegateOfUpdatesForFlagKeys:[LDFlagConfigValue flagKeys]];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
    [threadMock verify];
}

-(void)testNotifyDelegateOfUpdates_offline {
    [self.environment start];
    id threadMock = [OCMockObject niceMockForClass:[NSThread class]];
    [[threadMock reject] performOnMainThread:[OCMArg any] waitUntilDone:[OCMArg any]];

    [self.environment notifyDelegateOfUpdatesForFlagKeys:[LDFlagConfigValue flagKeys]];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
    [threadMock verify];
}

-(void)testNotifyDelegateOfUpdates_missingFlagKeys {
    [self.environment start];
    self.environment.online = YES;
    id threadMock = [OCMockObject niceMockForClass:[NSThread class]];
    [[threadMock reject] performOnMainThread:[OCMArg any] waitUntilDone:[OCMArg any]];

    [self.environment notifyDelegateOfUpdatesForFlagKeys:nil];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
    [threadMock verify];
}

-(void)testNotifyDelegateOfUpdates_emptyFlagKeys {
    [self.environment start];
    self.environment.online = YES;
    id threadMock = [OCMockObject niceMockForClass:[NSThread class]];
    [[threadMock reject] performOnMainThread:[OCMArg any] waitUntilDone:[OCMArg any]];

    [self.environment notifyDelegateOfUpdatesForFlagKeys:@[]];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
    [threadMock verify];
}

-(void)testNotifyDelegateOfUpdates_noDelegate {
    self.environment.delegate = nil;
    [self.environment start];
    self.environment.online = YES;
    id threadMock = [OCMockObject niceMockForClass:[NSThread class]];
    [[threadMock reject] performOnMainThread:[OCMArg any] waitUntilDone:[OCMArg any]];

    [self.environment notifyDelegateOfUpdatesForFlagKeys:[LDFlagConfigValue flagKeys]];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
    [threadMock verify];
}

-(void)testNotifyDelegateOfUpdates_delegateMethodNotImplemented {
    self.environment.delegate = (id<ClientDelegate>)[[NSObject alloc] init];
    [self.environment start];
    self.environment.online = YES;
    id threadMock = [OCMockObject niceMockForClass:[NSThread class]];
    [[threadMock reject] performOnMainThread:[OCMArg any] waitUntilDone:[OCMArg any]];

    [self.environment notifyDelegateOfUpdatesForFlagKeys:[LDFlagConfigValue flagKeys]];

    XCTAssertEqual(self.clientDelegateMock.featureFlagDidUpdateCallCount, 0);
    [threadMock verify];
}

- (void)testHandleServerUnavailable {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDServerConnectionUnavailableNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    XCTAssertEqual(self.clientDelegateMock.serverConnectionUnavailableCallCount, 1);
}

- (void)testHandleServerUnavailable_otherEnvironment {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDServerConnectionUnavailableNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:secondaryEnvironmentMobileKey}];

    XCTAssertEqual(self.clientDelegateMock.serverConnectionUnavailableCallCount, 0);
}

- (void)testHandleServerUnavailable_delegateDoesNotRespond {
    id clientDelegateMock = [OCMockObject niceMockForClass:[ClientDelegateProtocolWithoutMethodsMock class]];
    self.environment.delegate = clientDelegateMock;
    [self.environment start];
    self.environment.online = YES;
    [[clientDelegateMock reject] serverConnectionUnavailable];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDServerConnectionUnavailableNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    [clientDelegateMock verify];
}

- (void)testHandleClientUnauthorized {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    XCTAssertEqual(self.environment.isOnline, NO);
}

- (void)testHandleClientUnauthorized_otherEnvironment {
    [self.environment start];
    self.environment.online = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:secondaryEnvironmentMobileKey}];

    XCTAssertEqual(self.environment.isOnline, YES);
}

- (void)testHandleClientUnauthorized_delegateDoesNotRespond {
    id clientDelegateMock = [OCMockObject niceMockForClass:[ClientDelegateProtocolWithoutMethodsMock class]];
    self.environment.delegate = clientDelegateMock;
    [self.environment start];
    self.environment.online = YES;
    [[clientDelegateMock reject] serverConnectionUnavailable];

    [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];

    XCTAssertEqual(self.environment.isOnline, NO);
}

@end

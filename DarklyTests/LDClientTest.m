//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDClient.h"
#import "LDEnvironment.h"
#import "LDEnvironmentMock.h"
#import "LDEnvironmentController.h"
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
#import "ClientDelegateMock.h"
#import "LDConfig+Testable.h"
#import "NSURLSession+LaunchDarkly.h"

#import "OCMock.h"

@interface LDClient (LDClientTest)
@property (nonatomic, strong) LDUserModel *ldUser;
@property (nonatomic, strong) NSMutableDictionary<NSString*, LDEnvironment*> *secondaryEnvironments;    // <mobile-key: LDEnvironment>
@end

@implementation LDClient (LDClientTest)
@dynamic ldUser;
@dynamic secondaryEnvironments;
@end

@interface LDClientTest : DarklyXCTestCase <ClientDelegate>
@property (nonatomic, strong) XCTestExpectation *userConfigUpdatedNotificationExpectation;
@property (nonatomic, strong) id primaryEnvironmentMock;
@property (nonatomic, strong) id throttlerMock;
@property (nonatomic, strong) id nsUrlSessionMock;
@property (nonatomic, strong) LDUserBuilder *userBuilder;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) NSDictionary<NSString*, NSString*> *secondaryMobileKeys;  // <environment-name: mobile-key>
@property (nonatomic, strong) NSDictionary<NSString*, LDEnvironmentMock*> *secondaryEnvironmentMocks;  // <mobile-key: environment>
@property (nonatomic, strong) NSArray<NSString*> *ignoredUserAttributes;
@end

NSString *const kFallbackString = @"fallbackString";
NSString *const kTargetValueString = @"someString";
NSString *const kTestMobileKey = @"testMobileKey";

@implementation LDClientTest

- (void)setUp {
    [super setUp];

    self.ignoredUserAttributes = @[kUserAttributeUpdatedAt, kUserAttributeConfig];

    self.throttlerMock = [OCMockObject niceMockForClass:[LDThrottler class]];
    [[self.throttlerMock stub] runThrottled:[OCMArg invokeBlock]];
    [LDClient sharedInstance].throttler = self.throttlerMock;

    self.user = [LDUserModel stubWithKey:nil];
    self.userBuilder = [LDUserBuilder currentBuilder:self.user];

    self.config = [[LDConfig alloc] initWithMobileKey:kTestMobileKey];

    self.nsUrlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    [[[self.nsUrlSessionMock stub] andReturn:self] sharedSession];
    [[self.nsUrlSessionMock stub] setSharedLDSessionForConfig:self.config];

    self.primaryEnvironmentMock = [OCMockObject niceMockForClass:[LDEnvironment class]];
    [[[self.primaryEnvironmentMock stub] andReturn:self.primaryEnvironmentMock] environmentForMobileKey:kTestMobileKey config:self.config user:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isEqual:self.user ignoringAttributes:self.ignoredUserAttributes];
    }]];
}

- (void)setupSecondaryEnvironments {
    self.secondaryMobileKeys = [LDConfig secondaryMobileKeysStub];
    self.config.secondaryMobileKeys = self.secondaryMobileKeys;
    NSMutableDictionary<NSString*, LDEnvironmentMock*> *secondaryEnvironmentMocks = [NSMutableDictionary dictionaryWithCapacity:self.secondaryMobileKeys.count];
    for (NSString *mobileKey in self.secondaryMobileKeys.allValues) {
        LDEnvironmentMock *secondaryEnvironmentMock = [LDEnvironmentMock environmentMockForMobileKey:mobileKey config:self.config user:self.user];
        secondaryEnvironmentMocks[mobileKey] = secondaryEnvironmentMock;
        [[[self.primaryEnvironmentMock stub] andReturn:secondaryEnvironmentMock] environmentForMobileKey:[OCMArg checkWithBlock:^BOOL(id obj) {
            if (![obj isKindOfClass:[NSString class]]) {
                return NO;
            }
            NSString *environmentMobileKey = obj;
            if (![environmentMobileKey isEqualToString:mobileKey]) {
                return NO;
            }
            secondaryEnvironmentMock.environmentMockCallCount += 1;
            return YES;
        }] config:self.config user:[OCMArg checkWithBlock:^BOOL(id obj) {
            return [obj isEqual:self.user ignoringAttributes:self.ignoredUserAttributes];
        }]];
    }
    self.secondaryEnvironmentMocks = [secondaryEnvironmentMocks copy];
}

- (void)tearDown {
    [LDClient sharedInstance].primaryEnvironment = nil;
    [[LDClient sharedInstance] stopClient];
    [LDClient sharedInstance].ldUser = nil;
    [LDClient sharedInstance].secondaryEnvironments = nil;
    [LDClient sharedInstance].delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.user = nil;
    self.config = nil;
    self.nsUrlSessionMock = nil;
    self.throttlerMock = nil;
    self.userBuilder = nil;

    self.userConfigUpdatedNotificationExpectation = nil;
    [super tearDown];
}

#pragma mark - Properties

- (void)testSharedInstance {
    LDClient *first = [LDClient sharedInstance];
    LDClient *second = [LDClient sharedInstance];
    XCTAssertEqual(first, second);
}

-(void)testEnvironmentName {
    XCTAssertEqualObjects([LDClient sharedInstance].environmentName, kLDPrimaryEnvironmentName);
}

- (void)testDelegateSet {
    LDClient *ldClient = [LDClient sharedInstance];

    ldClient.delegate = (id<ClientDelegate>)self;
    XCTAssertEqualObjects(self, ldClient.delegate);
}

#pragma mark - SDK Control

- (void)testStart {
    self.nsUrlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    [[[self.nsUrlSessionMock stub] andReturn:self] sharedSession];
    [[self.nsUrlSessionMock expect] setSharedLDSessionForConfig:self.config];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] start];
    [[self.primaryEnvironmentMock expect] setOnline:YES];

    XCTAssertTrue([[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder]);

    XCTAssertTrue([[LDClient sharedInstance].ldUser isEqual:self.user ignoringAttributes:self.ignoredUserAttributes]);
    XCTAssertEqualObjects([LDClient sharedInstance].primaryEnvironment, self.primaryEnvironmentMock);
    XCTAssertEqual([LDClient sharedInstance].secondaryEnvironments.count, 0);
    [self.nsUrlSessionMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testStart_withSecondaryEnvironments {
    self.nsUrlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    [[[self.nsUrlSessionMock stub] andReturn:self] sharedSession];
    [self setupSecondaryEnvironments];
    [[self.nsUrlSessionMock expect] setSharedLDSessionForConfig:self.config];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] start];
    [[self.primaryEnvironmentMock expect] setOnline:YES];

    XCTAssertTrue([[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder]);

    XCTAssertTrue([[LDClient sharedInstance].ldUser isEqual:self.user ignoringAttributes:self.ignoredUserAttributes]);
    XCTAssertEqualObjects([LDClient sharedInstance].primaryEnvironment, self.primaryEnvironmentMock);  //self.environmentMock is configured to return self.environmentMock on a environmentForMobileKey msg
    [self.nsUrlSessionMock verify];
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.environmentMockCallCount, 1);
        XCTAssertEqual(environmentMock.startCallCount, 1);
        XCTAssertEqual(environmentMock.setOnlineCallCount, 1);
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, YES);
    }
}

- (void)testStart_withoutConfig {
    self.nsUrlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    [[[self.nsUrlSessionMock stub] andReturn:self] sharedSession];
    [[self.nsUrlSessionMock reject] setSharedLDSessionForConfig:[OCMArg any]];
    [(LDEnvironment*)[self.primaryEnvironmentMock reject] start];
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];

    XCTAssertFalse([[LDClient sharedInstance] start:nil withUserBuilder:nil]);

    XCTAssertNil([LDClient sharedInstance].primaryEnvironment);
    [self.nsUrlSessionMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testStart_multipleStartCalls {
    XCTAssertTrue([[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder]);
    [[self.nsUrlSessionMock reject] setSharedLDSessionForConfig:[OCMArg any]];
    [(LDEnvironment*)[self.primaryEnvironmentMock reject] start];
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];

    XCTAssertFalse([[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder]);

    XCTAssertEqualObjects([LDClient sharedInstance].primaryEnvironment, self.primaryEnvironmentMock);
    [self.nsUrlSessionMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testStart_withoutUser {
    self.nsUrlSessionMock = [OCMockObject niceMockForClass:[NSURLSession class]];
    [[[self.nsUrlSessionMock stub] andReturn:self] sharedSession];
    [[self.nsUrlSessionMock expect] setSharedLDSessionForConfig:self.config];
    self.primaryEnvironmentMock = [OCMockObject niceMockForClass:[LDEnvironment class]];
    [[[self.primaryEnvironmentMock stub] andReturn:self.primaryEnvironmentMock] environmentForMobileKey:kTestMobileKey config:self.config user:[OCMArg isKindOfClass:[LDUserModel class]]];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] start];
    [[self.primaryEnvironmentMock expect] setOnline:YES];

    XCTAssertTrue([[LDClient sharedInstance] start:self.config withUserBuilder:nil]);

    XCTAssertNotNil([LDClient sharedInstance].ldUser);
    XCTAssertEqualObjects([LDClient sharedInstance].primaryEnvironment, self.primaryEnvironmentMock);
    XCTAssertEqual([LDClient sharedInstance].secondaryEnvironments.count, 0);
    [self.nsUrlSessionMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testSetOnline_YES {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[LDClient sharedInstance] setOnline:NO];
    //The throttler mock is set to execute blocks. Setting the expectation on the environment mock verifies that the client is calling the throttler
    [[self.primaryEnvironmentMock expect] setOnline:YES];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertTrue([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.primaryEnvironmentMock verify];
}

- (void)testSetOnline_YES_withMultipleEnvironments {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[LDClient sharedInstance] setOnline:NO];
    //The throttler mock is set to execute blocks. Setting the expectation on the environment mock verifies that the client is calling the throttler
    [[self.primaryEnvironmentMock expect] setOnline:YES];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertTrue([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 3); //1st call from start, 2nd call from setOnline:NO in setup, 3rd call from setOnline:YES under test
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, YES);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_YES_withMultipleEnvironments_mismatchedPrimaryEnvironment {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock stub] andReturnValue:@NO] isOnline];
    //The throttler mock is set to execute blocks. Setting the expectation on the environment mock verifies that the client is calling the throttler
    [[self.primaryEnvironmentMock expect] setOnline:YES];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertTrue([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 2); //1st call from start, 2nd call from setOnline:YES under test
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, YES);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_YES_withMultipleEnvironments_mismatchedSecondaryEnvironment {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock stub] andReturnValue:@YES] isOnline];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        environmentMock.reportOnline = YES;
    }
    self.secondaryEnvironmentMocks.allValues.lastObject.reportOnline = NO;
    //The throttler mock is set to execute blocks. Setting the expectation on the environment mock verifies that the client is calling the throttler
    [[self.primaryEnvironmentMock expect] setOnline:YES];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertTrue([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 2); //1st call from start, 2nd call from setOnline:YES under test
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, YES);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_YES_withMultipleEnvironments_alreadyOnline {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock stub] andReturnValue:@YES] isOnline];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        environmentMock.reportOnline = YES;
    }
    //The throttler mock is set to execute blocks. Setting the expectation on the environment mock verifies that the client is calling the throttler
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertTrue([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 1); //1st call from start
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, YES);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_NO {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock expect] setOnline:NO];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testSetOnline_NO_withMultipleEnvironments {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock expect] setOnline:NO];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 2); //1st call from start, 2nd call from setOnline:NO under test
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, NO);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_NO_withMultipleEnvironments_mismatchedPrimaryEnvironment {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[LDClient sharedInstance] setOnline:NO];
    [[[self.primaryEnvironmentMock stub] andReturnValue:@YES] isOnline];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        environmentMock.reportOnline = NO;
    }
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock expect] setOnline:NO];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 3); //1st call from start, 2nd call from setOnline:NO in setup, 3rd call from setOnline:NO under test
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, NO);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_NO_withMultipleEnvironments_mismatchedSecondaryEnvironment {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[LDClient sharedInstance] setOnline:NO];
    [[[self.primaryEnvironmentMock stub] andReturnValue:@NO] isOnline];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        environmentMock.reportOnline = NO;
    }
    self.secondaryEnvironmentMocks.allValues.lastObject.reportOnline = YES;
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock expect] setOnline:NO];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 3); //1st call from start, 2nd call from setOnline:NO in setup, 3rd call from setOnline:NO under test
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, NO);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_NO_withMultipleEnvironments_alreadyOffline {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[LDClient sharedInstance] setOnline:NO];
    [[[self.primaryEnvironmentMock stub] andReturnValue:@NO] isOnline];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        environmentMock.reportOnline = NO;
    }
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.setOnlineCallCount, 2); //1st call from start, 2nd call from setOnline:NO in setup
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, NO);    //measures only the last setOnline call
    }
}

- (void)testSetOnline_YES_beforeStart {
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:YES completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testSetOnline_NO_beforeStart {
    [[self.throttlerMock reject] runThrottled:[OCMArg any]];
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];
    __block NSInteger completionCallCount = 0;

    [[LDClient sharedInstance] setOnline:NO completion: ^{
        completionCallCount += 1;
    }];

    XCTAssertFalse([LDClient sharedInstance].isOnline);
    XCTAssertEqual(completionCallCount, 1);
    [self.throttlerMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testFlush {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturnValue:@YES] flush];

    XCTAssertTrue([[LDClient sharedInstance] flush]);

    [self.primaryEnvironmentMock verify];
}

- (void)testFlush_multipleEnvironments {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturnValue:@YES] flush];

    XCTAssertTrue([[LDClient sharedInstance] flush]);

    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.flushCallCount, 1);
    }
    [self.primaryEnvironmentMock verify];
}

- (void)testFlush_withoutStart {
    [[self.primaryEnvironmentMock reject] flush];

    XCTAssertFalse([[LDClient sharedInstance] flush]);

    [self.primaryEnvironmentMock verify];
}

- (void)testStopClient {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[self.primaryEnvironmentMock expect] setOnline:NO];
    [[self.primaryEnvironmentMock expect] stop];

    XCTAssertTrue([[LDClient sharedInstance] stopClient]);

    XCTAssertEqual([LDClient sharedInstance].clientStarted, NO);
    XCTAssertEqual([LDClient sharedInstance].isOnline, NO);
    XCTAssertNil([LDClient sharedInstance].primaryEnvironment);
    [self.primaryEnvironmentMock verify];
}

- (void)testStopClient_withSecondaryEnvironments {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[self.primaryEnvironmentMock expect] setOnline:NO];
    [[self.primaryEnvironmentMock expect] stop];

    XCTAssertTrue([[LDClient sharedInstance] stopClient]);

    XCTAssertEqual([LDClient sharedInstance].clientStarted, NO);
    XCTAssertEqual([LDClient sharedInstance].isOnline, NO);
    XCTAssertNil([LDClient sharedInstance].primaryEnvironment);
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.stopCallCount, 1);
        XCTAssertEqual(environmentMock.setOnlineCallCount, 2);  //1st call from start. 2nd call from stop.
        XCTAssertEqual(environmentMock.setOnlineCalledValueOnline, NO); //Measures last setOnline call
    }
    XCTAssertEqual([LDClient sharedInstance].secondaryEnvironments.count, 0);   //Secondary environments removed
}

-(void)testStopClient_withoutStart {
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];
    [[self.primaryEnvironmentMock reject] stop];

    XCTAssertFalse([[LDClient sharedInstance] stopClient]);

    XCTAssertEqual([LDClient sharedInstance].clientStarted, NO);
    XCTAssertEqual([LDClient sharedInstance].isOnline, NO);
    XCTAssertNil([LDClient sharedInstance].primaryEnvironment);
    [self.primaryEnvironmentMock verify];
}

#pragma mark Deprecated
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)testDeprecatedStartWithValidConfig {
    id configBuilderMock = [OCMockObject niceMockForClass:[LDConfigBuilder class]];
    [[[configBuilderMock expect] andReturn:self.config] build];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] start];
    [[self.primaryEnvironmentMock expect] setOnline:YES];

    BOOL didStart = [[LDClient sharedInstance] start:configBuilderMock userBuilder:self.userBuilder];

    XCTAssertTrue(didStart);
    XCTAssertTrue([[LDClient sharedInstance].ldUser isEqual:self.user ignoringAttributes:self.ignoredUserAttributes]);
    XCTAssertEqualObjects([LDClient sharedInstance].primaryEnvironment, self.primaryEnvironmentMock);  //self.environmentMock is configured to return self.environmentMock on a environmentForMobileKey msg
    [configBuilderMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testDeprecatedStartWithValidConfigMultipleTimes {
    XCTAssertTrue([[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder]);
    id configBuilderMock = [OCMockObject niceMockForClass:[LDConfigBuilder class]];
    [[[configBuilderMock expect] andReturn:self.config] build];
    [(LDEnvironment*)[self.primaryEnvironmentMock reject] start];
    [[self.primaryEnvironmentMock reject] setOnline:[OCMArg any]];

    XCTAssertFalse([[LDClient sharedInstance] start:configBuilderMock userBuilder:self.userBuilder]);

    [configBuilderMock verify];
    [self.primaryEnvironmentMock verify];
}

- (void)testDeprecatedBoolVariationWithStart {
    id configBuilderMock = [OCMockObject niceMockForClass:[LDConfigBuilder class]];
    [[[configBuilderMock expect] andReturn:self.config] build];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] start];
    [[self.primaryEnvironmentMock expect] setOnline:YES];
    [[LDClient sharedInstance] start:configBuilderMock userBuilder:self.userBuilder];
    NSString *flagKey = @"test";
    [[[self.primaryEnvironmentMock expect] andReturnValue:@YES] boolVariation:flagKey fallback:NO];

    BOOL boolValue = [[LDClient sharedInstance] boolVariation:flagKey fallback:NO];

    XCTAssertTrue(boolValue);
    [configBuilderMock verify];
    [self.primaryEnvironmentMock verify];
}
#pragma clang diagnostic pop

#pragma mark - Variations
#pragma mark Bool Variation
- (void)testBoolVariation {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturnValue:@YES] boolVariation:kLDFlagKeyIsABool fallback:NO];

    BOOL flagValue = [[LDClient sharedInstance] boolVariation:kLDFlagKeyIsABool fallback:NO];

    XCTAssertEqual(flagValue, YES);
    [self.primaryEnvironmentMock verify];
}

- (void)testBoolVariation_withoutStart {
    [[self.primaryEnvironmentMock reject] boolVariation:[OCMArg any] fallback:[OCMArg any]];

    BOOL flagValue = [[LDClient sharedInstance] boolVariation:kLDFlagKeyIsABool fallback:YES];

    XCTAssertEqual(flagValue, YES);
    [self.primaryEnvironmentMock verify];
}

#pragma mark Number Variation
- (void)testNumberVariation {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturn:@7] numberVariation:kLDFlagKeyIsANumber fallback:@3];

    NSNumber *flagValue = [[LDClient sharedInstance] numberVariation:kLDFlagKeyIsANumber fallback:@3];

    XCTAssertEqualObjects(flagValue, @7);
    [self.primaryEnvironmentMock verify];
}

- (void)testNumberVariation_withoutStart {
    [[self.primaryEnvironmentMock reject] numberVariation:[OCMArg any] fallback:[OCMArg any]];

    NSNumber *flagValue = [[LDClient sharedInstance] numberVariation:kLDFlagKeyIsANumber fallback:@3];

    XCTAssertEqualObjects(flagValue, @3);
    [self.primaryEnvironmentMock verify];
}

#pragma mark Double Variation
- (void)testDoubleVariation {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturnValue:@(3.14159)] doubleVariation:kLDFlagKeyIsADouble fallback:2.71828];

    double flagValue = [[LDClient sharedInstance] doubleVariation:kLDFlagKeyIsADouble fallback:2.71828];

    XCTAssertEqual(flagValue, 3.14159);
    [self.primaryEnvironmentMock verify];
}

- (void)testDoubleVariation_withoutStart {
    [[[self.primaryEnvironmentMock reject] ignoringNonObjectArgs] doubleVariation:[OCMArg any] fallback:0];

    double flagValue = [[LDClient sharedInstance] doubleVariation:kLDFlagKeyIsADouble fallback:2.71828];

    XCTAssertEqual(flagValue, 2.71828);
    [self.primaryEnvironmentMock verify];
}

#pragma mark String Variation
- (void)testStringVariation {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturn:@"targetValue"] stringVariation:kLDFlagKeyIsAString fallback:@"fallbackValue"];

    NSString *flagValue = [[LDClient sharedInstance] stringVariation:kLDFlagKeyIsAString fallback:@"fallbackValue"];

    XCTAssertEqualObjects(flagValue, @"targetValue");
    [self.primaryEnvironmentMock verify];
}

- (void)testStringVariation_withoutStart {
    [[[self.primaryEnvironmentMock reject] ignoringNonObjectArgs] stringVariation:[OCMArg any] fallback:@"fallbackValue"];

    NSString *flagValue = [[LDClient sharedInstance] stringVariation:kLDFlagKeyIsAString fallback:@"fallbackValue"];

    XCTAssertEqual(flagValue, @"fallbackValue");
    [self.primaryEnvironmentMock verify];
}

#pragma mark Array Variation
- (void)testArrayVariation {
    NSArray *targetFlagValue = @[@3, @7];
    NSArray *fallbackFlagValue = @[@1, @2];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturn:targetFlagValue] arrayVariation:kLDFlagKeyIsAnArray fallback:fallbackFlagValue];

    NSArray *flagValue = [[LDClient sharedInstance] arrayVariation:kLDFlagKeyIsAnArray fallback:fallbackFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.primaryEnvironmentMock verify];
}

- (void)testArrayVariation_withoutStart {
    NSArray *fallbackFlagValue = @[@1, @2];
    [[self.primaryEnvironmentMock reject] arrayVariation:[OCMArg any] fallback:fallbackFlagValue];

    NSArray *flagValue = [[LDClient sharedInstance] arrayVariation:kLDFlagKeyIsAString fallback:fallbackFlagValue];

    XCTAssertEqual(flagValue, fallbackFlagValue);
    [self.primaryEnvironmentMock verify];
}

#pragma mark Dictionary Variation
- (void)testDictionaryVariation {
    NSDictionary *targetFlagValue = @{@"keyA":@YES, @"keyB":@[@1, @2, @3], @"keyC": @{@"keyD": @"someStringValue"}};
    NSDictionary *fallbackFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturn:targetFlagValue] dictionaryVariation:kLDFlagKeyIsADictionary fallback:fallbackFlagValue];

    NSDictionary *flagValue = [[LDClient sharedInstance] dictionaryVariation:kLDFlagKeyIsADictionary fallback:fallbackFlagValue];

    XCTAssertEqualObjects(flagValue, targetFlagValue);
    [self.primaryEnvironmentMock verify];
}

- (void)testDictionaryVariation_withoutStart {
    NSDictionary *fallbackFlagValue = @{@"key1": @"value1", @"key2": @[@1, @2]};
    [[self.primaryEnvironmentMock reject] dictionaryVariation:[OCMArg any] fallback:[OCMArg any]];

    NSDictionary *flagValue = [[LDClient sharedInstance] dictionaryVariation:kLDFlagKeyIsADictionary fallback:fallbackFlagValue];

    XCTAssertEqualObjects(flagValue, fallbackFlagValue);
    [self.primaryEnvironmentMock verify];
}

#pragma mark All Flags
-(void)testAllFlags {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [[[self.primaryEnvironmentMock expect] andReturn:self.user.flagConfig.allFlagValues] allFlags];

    NSDictionary<NSString*, id> *allFlags = [LDClient sharedInstance].allFlags;

    XCTAssertEqualObjects(allFlags, self.user.flagConfig.allFlagValues);
    [self.primaryEnvironmentMock verify];
}

-(void)testAllFlags_beforeStart {
    NSDictionary<NSString*, id> *allFlags = [LDClient.sharedInstance allFlags];

    XCTAssertNil(allFlags);
}

#pragma mark - Event Tracking

- (void)testTrack {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    NSDictionary *customData = @{@"key": @"value"};
    [[[self.primaryEnvironmentMock expect] andReturnValue:@YES] track:@"test" data:customData];

    XCTAssertTrue([[LDClient sharedInstance] track:@"test" data:customData]);

    [self.primaryEnvironmentMock verify];
}

- (void)testTrack_withoutStart {
    [[self.primaryEnvironmentMock reject] track:[OCMArg any] data:[OCMArg any]];

    XCTAssertFalse([[LDClient sharedInstance] track:@"test" data:nil]);

    [self.primaryEnvironmentMock verify];
}

#pragma mark - User

-(void)testUpdateUser {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    LDUserBuilder *newUserBuilder = [LDUserBuilder currentBuilder:newUser];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] updateUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isEqual:newUser ignoringAttributes:self.ignoredUserAttributes];
    }]];

    XCTAssertTrue([[LDClient sharedInstance] updateUser:newUserBuilder]);

    XCTAssertTrue([[LDClient sharedInstance].ldUser isEqual:newUser ignoringAttributes:self.ignoredUserAttributes]);
    [self.primaryEnvironmentMock verify];
}

-(void)testUpdateUser_withSecondaryEnvironments {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    LDUserBuilder *newUserBuilder = [LDUserBuilder currentBuilder:newUser];
    [(LDEnvironment*)[self.primaryEnvironmentMock expect] updateUser:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isEqual:newUser ignoringAttributes:self.ignoredUserAttributes];
    }]];

    XCTAssertTrue([[LDClient sharedInstance] updateUser:newUserBuilder]);

    XCTAssertTrue([[LDClient sharedInstance].ldUser isEqual:newUser ignoringAttributes:self.ignoredUserAttributes]);
    [self.primaryEnvironmentMock verify];
    for (LDEnvironmentMock *environmentMock in self.secondaryEnvironmentMocks.allValues) {
        XCTAssertEqual(environmentMock.updateUserCallCount, 1);
        XCTAssertTrue([environmentMock.updateUserCalledValueNewUser isEqual:newUser ignoringAttributes:self.ignoredUserAttributes]);
    }
}

- (void)testUpdateUser_withoutStart {
    [(LDEnvironment*)[self.primaryEnvironmentMock reject] updateUser:[OCMArg any]];

    XCTAssertFalse([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);

    XCTAssertNil([LDClient sharedInstance].ldUser);
    [self.primaryEnvironmentMock verify];
}

- (void)testUpdateUser_withoutBuilder {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];
    [(LDEnvironment*)[self.primaryEnvironmentMock reject] updateUser:[OCMArg any]];

    XCTAssertFalse([[LDClient sharedInstance] updateUser:nil]);

    XCTAssertTrue([[LDClient sharedInstance].ldUser isEqual:self.user ignoringAttributes:self.ignoredUserAttributes]);
    [self.primaryEnvironmentMock verify];
}

-(void)testCurrentUserBuilder {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];

    LDUserBuilder *userBuilder = [[LDClient sharedInstance] currentUserBuilder];

    LDUserModel *rebuiltUser = [userBuilder build];
    XCTAssertTrue([rebuiltUser isEqual:self.user ignoringAttributes:self.ignoredUserAttributes]);
}

- (void)testCurrentUserBuilder_withoutStart {
    XCTAssertNil([[LDClient sharedInstance] currentUserBuilder]);
}

#pragma mark - Multiple Environments

-(void)testEnvironmentForMobileKeyNamed {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];

    id<LDClientInterface> primaryEnvironment = [LDClient environmentForMobileKeyNamed:kLDPrimaryEnvironmentName];
    XCTAssertEqualObjects(primaryEnvironment, self.primaryEnvironmentMock);

    for (NSString *environmentName in self.secondaryMobileKeys.allKeys) {
        id<LDClientInterface> secondaryEnvironment = [LDClient environmentForMobileKeyNamed:environmentName];
        XCTAssertEqualObjects(secondaryEnvironment, self.secondaryEnvironmentMocks[self.secondaryMobileKeys[environmentName]]);
    }
}

-(void)testEnvironmentForMobileKeyNamed_singleEnvironment {
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];

    id<LDClientInterface> primaryEnvironment = [LDClient environmentForMobileKeyNamed:kLDPrimaryEnvironmentName];
    XCTAssertEqualObjects(primaryEnvironment, self.primaryEnvironmentMock);
}

-(void)testEnvironmentForMobileKeyNamed_badEnvironmentName {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];

    XCTAssertThrowsSpecificNamed([LDClient environmentForMobileKeyNamed:@"dummy-environment-name"], NSException, NSInvalidArgumentException);
}

-(void)testEnvironmentForMobileKeyNamed_missingEnvironmentName {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];

    XCTAssertThrowsSpecificNamed([LDClient environmentForMobileKeyNamed:nil], NSException, NSInvalidArgumentException);
}

-(void)testEnvironmentForMobileKeyNamed_emptyEnvironmentName {
    [self setupSecondaryEnvironments];
    [[LDClient sharedInstance] start:self.config withUserBuilder:self.userBuilder];

    XCTAssertThrowsSpecificNamed([LDClient environmentForMobileKeyNamed:@""], NSException, NSInvalidArgumentException);
}

-(void)testEnvironmentForMobileKeyNamed_notStarted {
    [self setupSecondaryEnvironments];

    id<LDClientInterface> primaryEnvironment = [LDClient environmentForMobileKeyNamed:kLDPrimaryEnvironmentName];
    XCTAssertNil(primaryEnvironment);

    for (NSString *environmentName in self.secondaryMobileKeys.allKeys) {
        id<LDClientInterface> secondaryEnvironment = [LDClient environmentForMobileKeyNamed:environmentName];
        XCTAssertNil(secondaryEnvironment);
    }
}

@end

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

#import <OCMock.h>

@interface LDClientTest : DarklyXCTestCase <ClientDelegate>

@end

@implementation LDClientTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [[LDClient sharedInstance] stopClient];
    [super tearDown];
}

- (void)testSharedInstance {
    LDClient *first = [LDClient sharedInstance];
    LDClient *second = [LDClient sharedInstance];
    XCTAssertEqual(first, second);
}

- (void)testStartWithoutConfig {
    XCTAssertFalse([[LDClient sharedInstance] start:nil userBuilder:nil]);
}

- (void)testStartWithValidConfig {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    LDClient *client = [LDClient sharedInstance];
    BOOL didStart = [client start:builder userBuilder:nil];
    XCTAssertTrue(didStart);
}

- (void)testStartWithValidConfigMultipleTimes {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    XCTAssertTrue([[LDClient sharedInstance] start:builder userBuilder:nil]);
    XCTAssertFalse([[LDClient sharedInstance] start:builder userBuilder:nil]);
}

- (void)testBoolVariationWithStart {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    BOOL boolValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(boolValue);
}

- (void)testUserPersisted {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    [userBuilder withKey:@"myKey"];
    [userBuilder withEmail:@"my@email.com"];
    
    [[LDClient sharedInstance] start:builder userBuilder:userBuilder];
    BOOL toggleValue = [[LDClient sharedInstance] boolVariation:@"test" fallback:YES];
    XCTAssertTrue(toggleValue);
    
    LDUserBuilder *anotherUserBuilder = [[LDUserBuilder alloc] init];
    [anotherUserBuilder withKey:@"myKey"];

    LDUserModel *user = [[LDClient sharedInstance] ldUser];
    OCMStub([self.dataManagerMock findUserWithkey:[OCMArg any]]).andReturn(user);

    [[LDClient sharedInstance] start:builder userBuilder:anotherUserBuilder];
    user = [[LDClient sharedInstance] ldUser];
    
     XCTAssertEqual(user.email, @"my@email.com");
}

-(void)testToggleCreatesEventWithCorrectArguments {
    NSString *toggleName = @"test";
    BOOL fallbackValue = YES;
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    OCMStub([self.dataManagerMock createFeatureEvent:[OCMArg any] keyValue:[OCMArg any] defaultKeyValue:[OCMArg any]]);
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    [[LDClient sharedInstance] boolVariation:toggleName fallback:fallbackValue];
    
    OCMVerify([self.dataManagerMock createFeatureEvent:toggleName keyValue:[NSNumber numberWithBool:fallbackValue] defaultKeyValue:[NSNumber numberWithBool:fallbackValue]]);
    [self.dataManagerMock stopMocking];
}

- (void)testTrackWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] track:@"test" data:nil]);
}

- (void)testTrackWithStart {
    NSDictionary *customData = @{@"key": @"value"};
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    
    
    OCMStub([self.dataManagerMock createCustomEvent:[OCMArg isKindOfClass:[NSString class]]  withCustomValuesDictionary:[OCMArg isKindOfClass:[NSDictionary class]]]);
    
    XCTAssertTrue([[LDClient sharedInstance] track:@"test" data:customData]);
    
    OCMVerify([self.dataManagerMock createCustomEvent: @"test"
                           withCustomValuesDictionary: customData]);
    
}

- (void)testOfflineWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] offline]);
}

- (void)testOfflineWithStart {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] offline]);
}


- (void)testOnlineWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] online]);
}

- (void)testOnlineWithStart {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] online]);
}

- (void)testFlushWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] flush]);
}

- (void)testFlushWithStart {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [[LDClient sharedInstance] start:builder userBuilder:nil];
    XCTAssertTrue([[LDClient sharedInstance] flush]);
}

- (void)testUpdateUserWithoutStart {
    XCTAssertFalse([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
}

-(void)testUpdateUserWithStart {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *configBuilder = [[LDConfigBuilder alloc] init];
    [configBuilder withMobileKey:testMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    
    LDClient *ldClient = [LDClient sharedInstance];
    [ldClient start:configBuilder userBuilder:userBuilder];
    
    XCTAssertTrue([[LDClient sharedInstance] updateUser:[[LDUserBuilder alloc] init]]);
}

- (void)testCurrentUserBuilderWithoutStart {
    XCTAssertNil([[LDClient sharedInstance] currentUserBuilder]);
}

-(void)testCurrentUserBuilderWithStart {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *configBuilder = [[LDConfigBuilder alloc] init];
    [configBuilder withMobileKey:testMobileKey];
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    
    LDClient *ldClient = [LDClient sharedInstance];
    [ldClient start:configBuilder userBuilder:userBuilder];
    
    XCTAssertNotNil([[LDClient sharedInstance] currentUserBuilder]);
}

- (void)testDelegateSet {
    LDClient *ldClient = [LDClient sharedInstance];
    
    ldClient.delegate = self;
    XCTAssertEqualObjects(self, ldClient.delegate);
}


@end

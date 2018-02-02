//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "LDConfig+Testable.h"
#import "DarklyXCTestCase.h"
#import "DarklyConstants.h"

@interface LDConfigTest : DarklyXCTestCase

@end

NSString * const LDConfigTestMobileKey = @"testMobileKey";

@implementation LDConfigTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConfigDefaultValues {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigBuilderDefaultValues {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:LDConfigTestMobileKey];
#pragma clang diagnostic pop
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideBaseUrl {
    NSString *testBaseUrl = @"testBaseUrl";
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    config.baseUrl = testBaseUrl;
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideStreamUrl {
    NSString *dummyStreamUrl = @"https://clientstream.launchdarkly.com/dummySSEUrl";
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"testMobileKey"];
    XCTAssertEqual(config.streamUrl, kStreamUrl);
    config.streamUrl = dummyStreamUrl;
    XCTAssertEqual(config.streamUrl, dummyStreamUrl);
}

- (void)testConfigOverrideCapacity {
    int testCapacity = 20;
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    config.capacity = [NSNumber numberWithInt:testCapacity];
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:testCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideConnectionTimeout {
    int testConnectionTimeout = 15;
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    config.connectionTimeout = [NSNumber numberWithInt:testConnectionTimeout];
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:testConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideFlushInterval {
    int testFlushInterval = 5;
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    config.flushInterval = [NSNumber numberWithInt:testFlushInterval];
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:testFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverridePollingInterval {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config pollingInterval], [NSNumber numberWithInt:kDefaultPollingInterval]);
    XCTAssertFalse([config debugEnabled]);

    NSNumber *pollingInterval = [NSNumber numberWithInt:5000];
    config.pollingInterval = pollingInterval;
    XCTAssertEqualObjects(config.pollingInterval, pollingInterval);

    pollingInterval = [NSNumber numberWithInt:50];
    config.pollingInterval = pollingInterval;
    XCTAssertEqualObjects([config pollingInterval], [NSNumber numberWithInt:kMinimumPollingInterval]);
}

- (void)testConfigOverrideStreaming {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    XCTAssertEqualObjects(config.mobileKey, LDConfigTestMobileKey);
    XCTAssertTrue(config.streaming);
    
    config.streaming = NO;
    XCTAssertFalse(config.streaming);
}

- (void)testConfigSetPrivateAttributes {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    XCTAssertNil(config.privateUserAttributes);

    config.privateUserAttributes = LDUserModel.allUserAttributes;
    XCTAssertEqualObjects(config.privateUserAttributes, LDUserModel.allUserAttributes);
}

- (void)testConfigOverrideDebug {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];
    config.debugEnabled = YES;
    XCTAssertEqualObjects([config mobileKey], LDConfigTestMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertTrue([config debugEnabled]);
}

- (void)testIsFlagRetryStatusCode {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:LDConfigTestMobileKey];

    NSMutableSet<NSNumber*> *selectedStatusCodes = [NSMutableSet setWithArray:@[@405, @400, @501, @200, @304, @307, @401, @404, @412, @500]];
    [selectedStatusCodes unionSet:[NSSet setWithArray:config.flagRetryStatusCodes]];    //allow flagRetryStatusCodes to change without changing the test
    NSMutableDictionary *statusCodeResults = [NSMutableDictionary dictionaryWithCapacity:selectedStatusCodes.count];
    [selectedStatusCodes enumerateObjectsUsingBlock:^(NSNumber * _Nonnull statusCode, BOOL * _Nonnull stop) {
        statusCodeResults[statusCode] = @([config.flagRetryStatusCodes containsObject:statusCode]);
    }];

    for (NSNumber *statusCode in [statusCodeResults allKeys]) {
        XCTAssertTrue([config isFlagRetryStatusCode:[statusCode integerValue]] == [statusCodeResults[statusCode] boolValue]);
    }
}

@end

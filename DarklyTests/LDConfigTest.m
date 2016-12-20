//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "DarklyXCTestCase.h"

@interface LDConfigTest : DarklyXCTestCase

@end

@implementation LDConfigTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConfigWithoutMobileKey {
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    XCTAssertNil([builder build]);
}

- (void)testConfigDefaultValues {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], testMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideBaseUrl {
    NSString *testMobileKey = @"testMobileKey";
    NSString *testBaseUrl = @"testBaseUrl";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [builder withBaseUrl:testBaseUrl];
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], testMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideCapacity {
    NSString *testMobileKey = @"testMobileKey";
    int testCapacity = 20;
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [builder withCapacity:testCapacity];
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], testMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:testCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideConnectionTimeout {
    NSString *testMobileKey = @"testMobileKey";
    int testConnectionTimeout = 15;
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [builder withConnectionTimeout:testConnectionTimeout];
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], testMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:testConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideFlushInterval {
    NSString *testMobileKey = @"testMobileKey";
    int testFlushInterval = 5;
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [builder withFlushInterval:testFlushInterval];
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], testMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:testFlushInterval]);
    XCTAssertFalse([config debugEnabled]);
}

- (void)testConfigOverrideDebug {
    NSString *testMobileKey = @"testMobileKey";
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    [builder withMobileKey:testMobileKey];
    [builder withDebugEnabled:YES];
    LDConfig *config = [builder build];
    XCTAssertEqualObjects([config mobileKey], testMobileKey);
    XCTAssertEqualObjects([config capacity], [NSNumber numberWithInt:kCapacity]);
    XCTAssertEqualObjects([config connectionTimeout], [NSNumber numberWithInt:kConnectionTimeout]);
    XCTAssertEqualObjects([config flushInterval], [NSNumber numberWithInt:kDefaultFlushInterval]);
    XCTAssertTrue([config debugEnabled]);
}

@end

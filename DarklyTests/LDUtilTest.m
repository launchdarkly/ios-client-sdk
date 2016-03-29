//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDUtil.h"

@interface LDUtilTest : XCTestCase

@end

@implementation LDUtilTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBase64EncodeString {
    NSString *input = @"{\"key\": \"test@test.com\", \"ip\": \"192.168.0.1\", \"custom\": {\"customer_ranking\": 10004}}";
    NSString *desired = @"eyJrZXkiOiAidGVzdEB0ZXN0LmNvbSIsICJpcCI6ICIxOTIuMTY4LjAuMSIsICJjdXN0b20iOiB7ImN1c3RvbWVyX3JhbmtpbmciOiAxMDAwNH19";
    NSString *output = [LDUtil base64EncodeString:input];
    XCTAssertEqualObjects(desired, output);
}

- (void)testBase64DecodeString {
    NSString *input = @"eyJrZXkiOiAidGVzdEB0ZXN0LmNvbSIsICJpcCI6ICIxOTIuMTY4LjAuMSIsICJjdXN0b20iOiB7ImN1c3RvbWVyX3JhbmtpbmciOiAxMDAwNH19";
    NSString *desired = @"{\"key\": \"test@test.com\", \"ip\": \"192.168.0.1\", \"custom\": {\"customer_ranking\": 10004}}";
    NSString *output = [LDUtil base64DecodeString:input];
    XCTAssertEqualObjects(desired, output);
}

@end

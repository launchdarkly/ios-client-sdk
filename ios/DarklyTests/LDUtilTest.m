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

- (void)testBase64UrlEncodeString {
    [[self unencodedStrings] enumerateObjectsUsingBlock:^(NSString *input, NSUInteger index, BOOL *stop) {
        XCTAssertTrue([[self base64UrlEncodedStrings][index] isEqualToString:[LDUtil base64UrlEncodeString: input]]);
    }];
}

- (void)testBase64UrlDecodeString {
    [[self base64UrlEncodedStrings] enumerateObjectsUsingBlock:^(NSString * _Nonnull input, NSUInteger index, BOOL * _Nonnull stop) {
        XCTAssertTrue([[self unencodedStrings][index] isEqualToString:[LDUtil base64UrlDecodeString: input]]);
    }];
}

//This list of strings was chosen so that the encoded values would contain a combination of the encoding specific characters and 0 to 2 padding characters
- (NSArray<NSString *> *)unencodedStrings {
    return @[@",\"city\":\"台北市 (Taipei)\"",
             @" \"city\" : \"屏東縣 (Pingtung)\",",
             @" \"city\" : \"Oakland\","
             ];
}

- (NSArray<NSString *> *)base64UrlEncodedStrings {
    return @[@"LCJjaXR5Ijoi5Y-w5YyX5biCIChUYWlwZWkpIg==",
             @"ICJjaXR5IiA6ICLlsY_mnbHnuKMgKFBpbmd0dW5nKSIs",
             @"ICJjaXR5IiA6ICJPYWtsYW5kIiw="
             ];
}

@end

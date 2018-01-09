//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDUserBuilder.h"
#import "LDUserModel.h"
#import "LDDataManager.h"
#import "DarklyXCTestCase.h"
#import "OCMock.h"

@interface LDUserBuilderTest : DarklyXCTestCase

@end

@implementation LDUserBuilderTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testUserDefaultValues {
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    LDUserModel *user = [builder build];
    XCTAssertNotNil([user key]);
    XCTAssertTrue([user anonymous]);
    XCTAssertNotNil([user device]);
    XCTAssertNotNil([user os]);
    XCTAssertNil([user privateAttributes]);
}

- (void)testUserWithInputValues {
    NSString *testKey = @"testKey";
    NSString *testIp = @"testIp";
    NSString *testCountry = @"testCountry";
    NSString *testName = @"testName";
    NSString *testFirstName = @"testFirstName";
    NSString *testLastName = @"testLastName";
    NSString *testEmail = @"testEmail";
    NSString *testAvatar = @"testAvatar";
    NSString *testCustomKey = @"testCustomKey";
    NSString *testCustomValue = @"testCustomValue";
    Boolean testAnonymous = NO;
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder.key = testKey;
    builder.ip = testIp;
    builder.country = testCountry;
    builder.name = testName;
    builder.firstName = testFirstName;
    builder.lastName = testLastName;
    builder.email = testEmail;
    builder.avatar = testAvatar;
    builder.customDictionary[testCustomKey] = testCustomValue;
    builder.isAnonymous = testAnonymous;

    LDUserModel *user = [builder build];
    XCTAssertEqualObjects([user key], testKey);
    XCTAssertEqualObjects([user ip], testIp);
    XCTAssertEqualObjects([user country], testCountry);
    XCTAssertEqualObjects([user name], testName);
    XCTAssertEqualObjects([user firstName], testFirstName);
    XCTAssertEqualObjects([user lastName], testLastName);
    XCTAssertEqualObjects([user email], testEmail);
    XCTAssertEqualObjects([user avatar], testAvatar);
    XCTAssertEqualObjects([[user custom] objectForKey:testCustomKey], testCustomValue);
    XCTAssertFalse([user anonymous]);
    XCTAssertNotNil([user device]);
    XCTAssertNotNil([user os]);
}

- (void)testUserSetAnonymous {
    Boolean testAnonymous = YES;
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder.isAnonymous = testAnonymous;
    LDUserModel *user = [builder build];
    XCTAssertTrue(user.anonymous);
}

- (void)testSetPrivateAttributes {
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    for (NSString *attribute in [LDUserModel allUserAttributes]) {
        builder.privateAttributes = @[attribute];
        LDUserModel *user = [builder build];
        XCTAssertEqualObjects(user.privateAttributes, @[attribute]);
    }

    builder.privateAttributes = [LDUserModel allUserAttributes];
    LDUserModel *user = [builder build];
    XCTAssertEqualObjects(user.privateAttributes, [LDUserModel allUserAttributes]);
}

@end

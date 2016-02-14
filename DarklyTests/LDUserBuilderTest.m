//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDUserBuilder.h"
#import "LDUserModel.h"
#import "LDDataManager.h"
#import "DarklyXCTestCase.h"
#import <OCMock.h>

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
}

- (void)testUserWithInputValues {
    NSString *testKey = @"testKey";
    NSString *testIp = @"testIp";
    NSString *testCountry = @"testCountry";
    NSString *testFirstName = @"testFirstName";
    NSString *testLastName = @"testLastName";
    NSString *testEmail = @"testEmail";
    NSString *testAvatar = @"testAvatar";
    NSString *testCustomKey = @"testCustomKey";
    NSString *testCustomValue = @"testCustomValue";
    Boolean testAnonymous = NO;
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder = [builder withKey:testKey];
    builder = [builder withIp:testIp];
    builder = [builder withCountry:testCountry];
    builder = [builder withFirstName:testFirstName];
    builder = [builder withLastName:testLastName];
    builder = [builder withEmail:testEmail];
    builder = [builder withAvatar:testAvatar];
    builder = [builder withCustomString:testCustomKey value:testCustomValue];
    builder = [builder withAnonymous:testAnonymous];    

    LDUserModel *user = [builder build];
    XCTAssertEqualObjects([user key], testKey);
    XCTAssertEqualObjects([user ip], testIp);
    XCTAssertEqualObjects([user country], testCountry);
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
    builder = [builder withAnonymous:testAnonymous];
    LDUserModel *user = [builder build];
    XCTAssertTrue([user anonymous]);
}

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDUserModel.h"

@interface UserTest : XCTestCase
@end

@implementation UserTest
- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testAnonymousSetToFalseIfKeySet {
    LDUserModel *user = [[LDUserModel alloc] init];
    
    user.key = @"aUser";
    
    XCTAssertFalse(user.anonymous);
}

-(void) testSettingUserKeyToNilOrBlank {
    LDUserModel *user = [[LDUserModel alloc] init];
    
    user.key = @"aUser";
    XCTAssertFalse(user.anonymous);
    
    user.key = nil;
    XCTAssertTrue(user.anonymous);
    XCTAssertNotNil(user.key);

    user.key = @"";
    XCTAssertTrue(user.anonymous);
    XCTAssertNotNil(user.key);
    
    user.key = @"notNil";
    XCTAssertFalse(user.anonymous);
    XCTAssertNotNil(user.key);

}

@end

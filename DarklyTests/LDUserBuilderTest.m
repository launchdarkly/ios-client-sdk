//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDUserBuilder.h"
#import "LDUserModel.h"
#import "LDUserModel+Testable.h"

@interface LDUserBuilder (LDUserBuilderTest)
+(NSString*)uniqueKey;
@end

@interface LDUserBuilderTest : DarklyXCTestCase

@end

@implementation LDUserBuilderTest

-(void)testBuild {
    LDUserModel *originalUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    LDUserBuilder *userBuilder = [LDUserBuilder currentBuilder:originalUser];

    LDUserModel *user = [userBuilder build];

    NSArray *ignoredAttributes = @[kUserAttributeConfig, kUserAttributeUpdatedAt];
    XCTAssertTrue([user isEqual:originalUser ignoringAttributes:ignoredAttributes]);
}

-(void)testBuild_emptyProperties {
    LDUserModel *targetUser = [[LDUserModel alloc] init];
    targetUser.key = [LDUserBuilder uniqueKey];
    targetUser.anonymous = YES;
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];

    LDUserModel *user = [userBuilder build];

    XCTAssertTrue([user isEqual:targetUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
}

- (void)testBuild_setAnonymous {
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder.key = [[NSUUID UUID] UUIDString];
    builder.isAnonymous = YES;

    LDUserModel *user = [builder build];

    XCTAssertEqualObjects(user.key, builder.key);
    XCTAssertTrue(user.anonymous);
}

- (void)testBuild_privateAttributes {
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

- (void)testBuild_allPrivateAttributes {
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder.privateAttributes = [LDUserModel allUserAttributes];

    LDUserModel *user = [builder build];

    XCTAssertEqualObjects(user.privateAttributes, [LDUserModel allUserAttributes]);
}

@end

//
//  LDUserEnvironmentTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDUserEnvironment.h"
#import "LDUserEnvironment+Testable.h"
#import "LDUserModel.h"
#import "LDUserModel+Testable.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDEventTrackingContext.h"
#import "NSDictionary+Testable.h"
#import "NSDate+ReferencedDate.h"

@interface LDUserEnvironmentTest : DarklyXCTestCase
@property (nonatomic, strong) NSString *userKey;
@property (nonatomic, strong) NSDictionary<NSString*, LDUserModel*> *users;
@property (nonatomic, strong) LDUserEnvironment *userEnvironment;
@end

@implementation LDUserEnvironmentTest

-(void)setUp {
    [super setUp];

    self.userKey = [[NSUUID UUID] UUIDString];
    self.users = [LDUserEnvironment stubUserModelsForUserWithKey:self.userKey environmentKeys:LDUserEnvironment.environmentKeys];

    self.userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:self.userKey environments:self.users];
}

-(void)tearDown {
    [super tearDown];
}

-(void)testInitAndConstructor {
    XCTAssertEqualObjects(self.userEnvironment.userKey, self.userKey);
    XCTAssertTrue([self.userEnvironment.users isEqualToUserEnvironmentUsersDictionary:self.users]);
}

-(void)testInitAndConstructor_mismatchedUserKey {
    NSString *mismatchedKey = [[NSUUID UUID] UUIDString];
    self.userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:mismatchedKey environments:self.users];

    XCTAssertEqualObjects(self.userEnvironment.userKey, mismatchedKey);
    XCTAssertNotNil(self.userEnvironment.users);
    XCTAssertTrue(self.userEnvironment.users.count == 0);
}

-(void)testInitAndConstructor_missingKey {
    NSString *missingUserKey;
    self.userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:missingUserKey environments:self.users];

    XCTAssertNil(self.userEnvironment);
}

-(void)testInitAndConstructor_missingEnvironments {
    self.userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:self.userKey environments:nil];

    XCTAssertEqualObjects(self.userEnvironment.userKey, self.userKey);
    XCTAssertNotNil(self.userEnvironment.users);
    XCTAssertTrue(self.userEnvironment.users.count == 0);
}

-(void)testInitAndConstructor_invalidEnvironment {
    NSMutableDictionary *environmentsWithInvalidItem = [NSMutableDictionary dictionaryWithDictionary:self.users];
    environmentsWithInvalidItem[@"invalidItemKey"] = @"invalid item";
    self.userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:self.userKey environments:[environmentsWithInvalidItem copy]];

    XCTAssertEqualObjects(self.userEnvironment.userKey, self.userKey);
    XCTAssertTrue([self.userEnvironment.users isEqualToUserEnvironmentUsersDictionary:self.users]);
}

-(void)testEncodeAndDecodeWithCoder {
    NSData *userEnvironmentData = [NSKeyedArchiver archivedDataWithRootObject:self.userEnvironment];
    XCTAssertNotNil(userEnvironmentData);

    LDUserEnvironment *restoredUserEnvironment = [NSKeyedUnarchiver unarchiveObjectWithData:userEnvironmentData];
    XCTAssertTrue([restoredUserEnvironment isEqualToUserEnvironment:restoredUserEnvironment]);
}

-(void)testEncodeAndDecodeWithCoder_missingKey {
    self.userEnvironment.userKey = nil;
    NSData *userEnvironmentData = [NSKeyedArchiver archivedDataWithRootObject:self.userEnvironment];
    XCTAssertNotNil(userEnvironmentData);

    LDUserEnvironment *restoredUserEnvironment = [NSKeyedUnarchiver unarchiveObjectWithData:userEnvironmentData];
    XCTAssertNil(restoredUserEnvironment);
}

-(void)testEncodeAndDecodeWithCoder_missingEnvironments {
    self.userEnvironment.users = nil;
    NSData *userEnvironmentData = [NSKeyedArchiver archivedDataWithRootObject:self.userEnvironment];
    XCTAssertNotNil(userEnvironmentData);

    LDUserEnvironment *restoredUserEnvironment = [NSKeyedUnarchiver unarchiveObjectWithData:userEnvironmentData];
    XCTAssertEqualObjects(restoredUserEnvironment.userKey, self.userKey);
    XCTAssertNotNil(restoredUserEnvironment.users);
    XCTAssertTrue(restoredUserEnvironment.users.count == 0);
}

-(void)testDictionaryValueAndInitWithDictionary {
    NSDictionary *userEnvironmentDictionary = [self.userEnvironment dictionaryValue];

    LDUserEnvironment *restoredUserEnvironment = [[LDUserEnvironment alloc] initWithDictionary:userEnvironmentDictionary];
    XCTAssertTrue([restoredUserEnvironment isEqualToUserEnvironment:restoredUserEnvironment]);
}

-(void)testDictionaryValueAndInitWithDictionary_missingKey {
    self.userEnvironment.userKey = nil;
    NSDictionary *userEnvironmentDictionary = [self.userEnvironment dictionaryValue];

    LDUserEnvironment *restoredUserEnvironment = [[LDUserEnvironment alloc] initWithDictionary:userEnvironmentDictionary];
    XCTAssertNil(restoredUserEnvironment);
}

-(void)testDictionaryValueAndInitWithDictionary_missingUsers {
    self.userEnvironment.users = nil;
    NSDictionary *userEnvironmentDictionary = [self.userEnvironment dictionaryValue];

    LDUserEnvironment *restoredUserEnvironment = [[LDUserEnvironment alloc] initWithDictionary:userEnvironmentDictionary];
    XCTAssertEqualObjects(restoredUserEnvironment.userKey, self.userKey);
    XCTAssertNotNil(restoredUserEnvironment.users);
    XCTAssertTrue(restoredUserEnvironment.users.count == 0);
}

-(void)testLastUpdated {
    for (LDUserModel *userInEnvironment in self.userEnvironment.users.allValues) {
        //lastUpdated should be the latest updatedAt of all users.
        XCTAssertTrue([self.userEnvironment.lastUpdated isLaterThan:userInEnvironment.updatedAt] || [self.userEnvironment.lastUpdated isEqualToDate:userInEnvironment.updatedAt]);
    }
}

-(void)testLastUpdated_singleEnvironment {
    LDUserModel *user = self.users[kEnvironmentKeyPrimary];
    LDUserEnvironment *userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:self.userKey environments:@{kEnvironmentKeyPrimary: user}];

    XCTAssertTrue([userEnvironment.lastUpdated isEqualToDate:user.updatedAt]);
}

-(void)testLastUpdated_missingEnvironments {
    LDUserEnvironment *userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:self.userKey environments:nil];

    XCTAssertNil(userEnvironment.lastUpdated);
}

-(void)testUserForMobileKey {
    for (NSString *mobileKey in self.users.allKeys) {
        LDUserModel *targetUser = self.users[mobileKey];

        LDUserModel *foundUser = [self.userEnvironment userForMobileKey:mobileKey];

        XCTAssertTrue([foundUser isEqual:targetUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    }
}

-(void)testUserForMobileKey_mobileKeyNotFound {
    LDUserModel *foundUser = [self.userEnvironment userForMobileKey:[[NSUUID UUID] UUIDString]];

    XCTAssertNil(foundUser);
}

-(void)testUserForMobileKey_missingMobileKey {
    NSString *missingUserKey;
    LDUserModel *foundUser = [self.userEnvironment userForMobileKey:missingUserKey];

    XCTAssertNil(foundUser);
}

-(void)testSetUserForMobileKey {
    LDUserModel *newUser = [LDUserModel stubWithKey:self.userKey];
    NSString *newMobileKey = [[NSUUID UUID] UUIDString];

    [self.userEnvironment setUser:newUser mobileKey:newMobileKey];

    XCTAssertTrue([[self.userEnvironment userForMobileKey:newMobileKey] isEqual:newUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    for (NSString *mobileKey in self.users.allKeys) {
        XCTAssertTrue([[self.userEnvironment userForMobileKey:mobileKey] isEqual:self.users[mobileKey] ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    }
}

-(void)testSetUserForMobileKey_missingMobileKey {
    LDUserModel *newUser = [LDUserModel stubWithKey:self.userKey];
    NSString *missingMobileKey;

    [self.userEnvironment setUser:newUser mobileKey:missingMobileKey];

    XCTAssertNil([self.userEnvironment userForMobileKey:missingMobileKey]);
    for (NSString *mobileKey in self.users.allKeys) {
        XCTAssertTrue([[self.userEnvironment userForMobileKey:mobileKey] isEqual:self.users[mobileKey] ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    }
}

-(void)testSetUserForMobileKey_mismatchedUserKey {
    LDUserModel *newUser = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    NSString *newMobileKey = [[NSUUID UUID] UUIDString];

    [self.userEnvironment setUser:newUser mobileKey:newMobileKey];

    XCTAssertNil([self.userEnvironment userForMobileKey:newMobileKey]);
    for (NSString *mobileKey in self.users.allKeys) {
        XCTAssertTrue([[self.userEnvironment userForMobileKey:mobileKey] isEqual:self.users[mobileKey] ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    }
}

-(void)testSetUserForMobileKey_missingUserKey {
    LDUserModel *newUser = [LDUserModel stubWithKey:self.userKey];
    newUser.key = nil;
    NSString *newMobileKey = [[NSUUID UUID] UUIDString];

    [self.userEnvironment setUser:newUser mobileKey:newMobileKey];

    XCTAssertNil([self.userEnvironment userForMobileKey:newMobileKey]);
    for (NSString *mobileKey in self.users.allKeys) {
        XCTAssertTrue([[self.userEnvironment userForMobileKey:mobileKey] isEqual:self.users[mobileKey] ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    }
}

-(void)testRemoveUserForMobileKey {
    NSUInteger remainingUserCount = self.users.count;
    for (NSString *mobileKey in self.users.allKeys) {
        [self.userEnvironment removeUserForMobileKey:mobileKey];
        remainingUserCount -= 1;

        XCTAssertNil([self.userEnvironment userForMobileKey:mobileKey]);
        XCTAssertEqual(self.userEnvironment.users.count, remainingUserCount);
    }
}

-(void)testRemoveUserForMobileKey_missingMobileKey {
    NSString *missingMobileKey;

    [self.userEnvironment removeUserForMobileKey:missingMobileKey];

    XCTAssertEqual(self.userEnvironment.users.count, self.users.count);
}

-(void)testRemoveUserForMobileKey_mobileKeyNotFound {
    NSString *notFoundMobileKey = [[NSUUID UUID] UUIDString];

    [self.userEnvironment removeUserForMobileKey:notFoundMobileKey];

    XCTAssertEqual(self.userEnvironment.users.count, self.users.count);
}

@end

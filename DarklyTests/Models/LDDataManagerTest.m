//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDFlagConfigModel.h"
#import "LDDataManager.h"
#import "LDDataManager+Testable.h"
#import "LDUserModel.h"
#import "LDUserModel+Testable.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDEventModel.h"
#import "LDEventModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"
#import "LDClient.h"
#import "OCMock.h"
#import "LDDataManager+Testable.h"
#import "LDFlagConfigTracker.h"
#import "LDFlagConfigTracker+Testable.h"
#import "LDConfig.h"
#import "LDConfig+LaunchDarkly.h"
#import "LDConfig+Testable.h"
#import "NSDate+Testable.h"
#import "NSArray+Testable.h"
#import "NSNumber+LaunchDarkly.h"
#import "LDUserEnvironment+Testable.h"
#import "NSDictionary+LaunchDarkly.h"

NSString * const kMobileKeyMock = @"LDDataManagerTest.mobileKeyMock";
extern NSString * const kUserDefaultsKeyUserEnvironments;

@interface LDDataManager (LDDataManagerTest)
-(NSMutableDictionary*)retrieveStoredUserModels;
+(nonnull NSMutableDictionary<NSString*,LDUserModel*>*)retrieveStoredUserModels;
+(void)storeUserModels:(NSDictionary *)userModels;
+(NSDictionary<NSString*, LDUserEnvironment*>*)retrieveUserEnvironments;
+(void)saveUserEnvironments:(NSDictionary<NSString*, LDUserEnvironment*>*)userEnvironments;
-(void)saveEnvironmentForUser:(LDUserModel*)user completion:(void (^)(void))completion;
-(void)saveUser:(LDUserModel*)user asDict:(BOOL)asDict completion:(void (^)(void))completion;
-(void)saveUserEnvironments:(NSDictionary<NSString*, LDUserEnvironment*>*)userEnvironments;
-(NSDictionary<NSString*, LDUserEnvironment*>*)retrieveUserEnvironments;
-(void)discardEventsDictionary;
+(void)removeStoredUsers;
@end

@interface LDDataManagerTest : DarklyXCTestCase
@property (nonatomic, strong) id eventModelMock;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDDataManager *dataManager;
@end

@implementation LDDataManagerTest

- (void)setUp {
    [super setUp];
    [LDDataManager removeStoredUsers];
    self.config = [[LDConfig alloc] initWithMobileKey:kMobileKeyMock];
    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    self.user.flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls" eventTrackingContext:nil];   //NSNull can't go into the user cache in NSUserDefaults
    self.dataManager = [LDDataManager dataManagerWithMobileKey:self.config.mobileKey config:self.config];
}

- (void)tearDown {
    [self.eventModelMock stopMocking];
    self.eventModelMock = nil;
    [self.dataManager discardEventsDictionary];
    [LDDataManager removeStoredUsers];
    [super tearDown];
}

-(LDFlagConfigValue*)setupCreateFeatureEventTestWithTrackEvents:(BOOL)trackEvents {
    return [self setupCreateFeatureEventTestWithTrackEvents:trackEvents includeTrackingContext:YES];
}

-(LDFlagConfigValue*)setupCreateFeatureEventTestWithTrackEvents:(BOOL)trackEvents includeTrackingContext:(BOOL)includeTrackingContext {
    LDEventTrackingContext *eventTrackingContext = includeTrackingContext ? [LDEventTrackingContext contextWithTrackEvents:trackEvents debugEventsUntilDate:nil] : nil;
    self.user = [LDUserModel stubWithKey:nil usingTracker:nil eventTrackingContext:eventTrackingContext];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kFlagKeyIsABawler];
    LDEventModel *featureEvent = [LDEventModel featureEventWithFlagKey:kFlagKeyIsABawler
                                                     reportedFlagValue:flagConfigValue.value
                                                       flagConfigValue:flagConfigValue
                                                      defaultFlagValue:@(NO)
                                                                  user:self.user
                                                            inlineUser:NO];
    self.eventModelMock = OCMClassMock([LDEventModel class]);
    OCMStub(ClassMethod([self.eventModelMock featureEventWithFlagKey:[OCMArg any]
                                                   reportedFlagValue:[OCMArg any]
                                                     flagConfigValue:[OCMArg any]
                                                    defaultFlagValue:[OCMArg any]
                                                                user:[OCMArg any]
                                                          inlineUser:[OCMArg any]]))
    .andReturn(featureEvent);

    return flagConfigValue;
}

-(LDFlagConfigValue*)setupCreateDebugEventTestWithLastEventResponseDate:(NSDate*)lastResponse debugUntil:(NSDate*)debugUntil {
    return [self setupCreateDebugEventTestWithLastEventResponseDate:lastResponse debugUntil:debugUntil includeTrackingContext:YES];
}

-(LDFlagConfigValue*)setupCreateDebugEventTestWithLastEventResponseDate:(NSDate*)lastResponse debugUntil:(NSDate*)debugUntil includeTrackingContext:(BOOL)includeTrackingContext {
    self.dataManager.lastEventResponseDate = lastResponse;
    LDEventTrackingContext *eventTrackingContext = includeTrackingContext ? [LDEventTrackingContext contextWithTrackEvents:NO debugEventsUntilDate:debugUntil] : nil;
    self.user = [LDUserModel stubWithKey:nil usingTracker:nil eventTrackingContext:eventTrackingContext];
    LDFlagConfigValue *flagConfigValue = [self.user.flagConfig flagConfigValueForFlagKey:kFlagKeyIsABawler];
    LDEventModel *debugEvent = [LDEventModel debugEventWithFlagKey:kFlagKeyIsABawler reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultFlagValue:@(NO) user:self.user];
    self.eventModelMock = OCMClassMock([LDEventModel class]);
    OCMStub(ClassMethod([self.eventModelMock featureEventWithFlagKey:[OCMArg any]
                                                   reportedFlagValue:[OCMArg any]
                                                     flagConfigValue:[OCMArg any]
                                                    defaultFlagValue:[OCMArg any]
                                                                user:[OCMArg any]
                                                          inlineUser:[OCMArg any]]))
    .andReturn(debugEvent);

    return flagConfigValue;
}

-(void)testInitAndConstructor {
    LDDataManager *dataManager = [LDDataManager dataManagerWithMobileKey:self.config.mobileKey config:self.config];

    XCTAssertNotNil(dataManager);
    XCTAssertEqualObjects(dataManager.mobileKey, self.config.mobileKey);
    XCTAssertEqualObjects(dataManager.config, self.config);
    XCTAssertNotNil(dataManager.eventsArray);
    XCTAssertEqual(dataManager.eventsArray.count, 0);
    XCTAssertNotNil(dataManager.eventsQueue);
    XCTAssertNotNil(dataManager.saveUserQueue);
}

-(void)testInitAndConstructor_missingMobileKey {
    NSString *missingMobileKey;
    LDDataManager *dataManager = [LDDataManager dataManagerWithMobileKey:missingMobileKey config:self.config];

    XCTAssertNil(dataManager);
}

-(void)testInitAndConstructor_emptyMobileKey {
    LDDataManager *dataManager = [LDDataManager dataManagerWithMobileKey:@"" config:self.config];

    XCTAssertNil(dataManager);
}

-(void)testInitAndConstructor_missingConfig {
    LDConfig *missingConfig;
    LDDataManager *dataManager = [LDDataManager dataManagerWithMobileKey:self.config.mobileKey config:missingConfig];

    XCTAssertNil(dataManager);
}

-(void)testConvertToEnvironmentBasedCache {
    self.config.secondaryMobileKeys = [LDConfig secondaryMobileKeysStub];
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserModel*> *users = [LDUserModel stubUsersWithKeys:userKeys];
    [LDDataManager storeUserModels:users];

    for (NSString *userKey in userKeys) {
        [LDDataManager convertToEnvironmentBasedCacheForUser:users[userKey] config:self.config];
    }

    NSDictionary<NSString*, LDUserEnvironment*> *cachedEnvironments = [LDDataManager retrieveUserEnvironments];
    NSDictionary<NSString*, LDUserModel*> *cachedUsers = [LDDataManager retrieveStoredUserModels];
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *cachedEnvironment = cachedEnvironments[userKey];
        XCTAssertNotNil(cachedEnvironment);
        if (cachedEnvironment == nil) { continue; }
        XCTAssertEqualObjects(cachedEnvironment.userKey, userKey);
        LDUserModel *originalUser = users[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            XCTAssertTrue([cachedEnvironment.users[mobileKey] isEqual:originalUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
        }
        XCTAssertEqual(cachedEnvironment.users.count, self.config.mobileKeys.count);
        XCTAssertNotNil(cachedUsers[userKey]);  //Even though the cached user was converted to a UserEnvironment, the cached user remains until the second call to convert the cache
    }
}

-(void)testConvertToEnvironmentBasedCache_singleEnvironment {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserModel*> *users = [LDUserModel stubUsersWithKeys:userKeys];
    [LDDataManager storeUserModels:users];

    for (NSString *userKey in userKeys) {
        [LDDataManager convertToEnvironmentBasedCacheForUser:users[userKey] config:self.config];
    }

    NSDictionary<NSString*, LDUserEnvironment*> *cachedEnvironments = [LDDataManager retrieveUserEnvironments];
    NSDictionary<NSString*, LDUserModel*> *cachedUsers = [LDDataManager retrieveStoredUserModels];
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *cachedEnvironment = cachedEnvironments[userKey];
        XCTAssertNotNil(cachedEnvironment);
        if (cachedEnvironment == nil) { continue; }
        XCTAssertEqualObjects(cachedEnvironment.userKey, userKey);
        LDUserModel *originalUser = users[userKey];
        XCTAssertTrue([cachedEnvironment.users[self.config.mobileKey] isEqual:originalUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
        XCTAssertEqual(cachedEnvironment.users.count, 1);
        XCTAssertNotNil(cachedUsers[userKey]);  //Even though the cached user was converted to a UserEnvironment, the cached user remains until the second call to convert the cache
    }
}

-(void)testConvertToEnvironmentBasedCache_missingUser {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserModel*> *users = [LDUserModel stubUsersWithKeys:userKeys];
    [LDDataManager storeUserModels:users];
    LDUserModel *missingUser;

    [LDDataManager convertToEnvironmentBasedCacheForUser:missingUser config:self.config];

    XCTAssertTrue([LDDataManager retrieveUserEnvironments].count == 0);
}

-(void)testConvertToEnvironmentBasedCache_missingConfig {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserModel*> *users = [LDUserModel stubUsersWithKeys:userKeys];
    [LDDataManager storeUserModels:users];
    LDConfig *missingConfig;

    [LDDataManager convertToEnvironmentBasedCacheForUser:self.user config:missingConfig];

    XCTAssertTrue([LDDataManager retrieveUserEnvironments].count == 0);
}

-(void)testConvertToEnvironmentBasedCache_secondCall {
    //After the first call to convert, there should be both a set of userEnvironments and a set of userModels. In that state, the method should just delete the userModel for the user
    self.config.secondaryMobileKeys = [LDConfig secondaryMobileKeysStub];
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserModel*> *users = [LDUserModel stubUsersWithKeys:userKeys];
    [LDDataManager storeUserModels:users];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys mobileKeys:self.config.mobileKeys];
    [LDDataManager saveUserEnvironments:userEnvironments];

    for (NSString *userKey in userKeys) {
        [LDDataManager convertToEnvironmentBasedCacheForUser:users[userKey] config:self.config];
    }

    NSDictionary<NSString*, LDUserEnvironment*> *cachedEnvironments = [LDDataManager retrieveUserEnvironments];
    NSDictionary<NSString*, LDUserModel*> *cachedUsers = [LDDataManager retrieveStoredUserModels];
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *cachedEnvironment = cachedEnvironments[userKey];
        XCTAssertNotNil(cachedEnvironment);
        if (cachedEnvironment == nil) { continue; }
        XCTAssertEqualObjects(cachedEnvironment.userKey, userKey);
        LDUserEnvironment *originalEnvironment = userEnvironments[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            LDUserModel *originalUser = originalEnvironment.users[mobileKey];
            XCTAssertTrue([cachedEnvironment.users[mobileKey] isEqual:originalUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
        }
        XCTAssertNil(cachedUsers[userKey]);  //Since there was a user environment on the second call to convert, the old user cache should no longer have the user
    }
}

-(void)testConvertToEnvironmentBasedCache_noMatchingUserOrEnvironment {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserModel*> *users = [LDUserModel stubUsersWithKeys:userKeys];
    [LDDataManager storeUserModels:users];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys mobileKeys:self.config.mobileKeys];
    [LDDataManager saveUserEnvironments:userEnvironments];
    LDUserModel *uncachedUser = [LDUserModel stubWithKey:[NSUUID UUID].UUIDString];

    [LDDataManager convertToEnvironmentBasedCacheForUser:uncachedUser config:self.config];

    NSDictionary<NSString*, LDUserEnvironment*> *cachedEnvironments = [LDDataManager retrieveUserEnvironments];
    NSDictionary<NSString*, LDUserModel*> *cachedUsers = [LDDataManager retrieveStoredUserModels];
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *cachedEnvironment = cachedEnvironments[userKey];
        XCTAssertNotNil(cachedEnvironment);
        if (cachedEnvironment == nil) { continue; }
        XCTAssertEqualObjects(cachedEnvironment.userKey, userKey);
        LDUserEnvironment *originalEnvironment = userEnvironments[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            LDUserModel *originalUser = originalEnvironment.users[mobileKey];
            XCTAssertTrue([cachedEnvironment.users[mobileKey] isEqual:originalUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
        }
        XCTAssertNotNil(cachedUsers[userKey]);  //Make sure other users have not been affected
    }
}

-(void)testConvertToEnvironmentBasedCache_noMatchingUser {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSMutableDictionary<NSString*, LDUserModel*> *users = [NSMutableDictionary dictionaryWithDictionary:[LDUserModel stubUsersWithKeys:userKeys]];
    LDUserModel *uncachedUser = users[userKeys.firstObject];
    [users removeObjectForKey:userKeys.firstObject];
    [LDDataManager storeUserModels:users];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys mobileKeys:self.config.mobileKeys];
    [LDDataManager saveUserEnvironments:userEnvironments];

    [LDDataManager convertToEnvironmentBasedCacheForUser:uncachedUser config:self.config];

    NSDictionary<NSString*, LDUserEnvironment*> *cachedEnvironments = [LDDataManager retrieveUserEnvironments];
    NSDictionary<NSString*, LDUserModel*> *cachedUsers = [LDDataManager retrieveStoredUserModels];
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *cachedEnvironment = cachedEnvironments[userKey];
        XCTAssertNotNil(cachedEnvironment);
        if (cachedEnvironment == nil) { continue; }
        XCTAssertEqualObjects(cachedEnvironment.userKey, userKey);
        LDUserEnvironment *originalEnvironment = userEnvironments[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            LDUserModel *originalUser = originalEnvironment.users[mobileKey];
            XCTAssertTrue([cachedEnvironment.users[mobileKey] isEqual:originalUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
        }
        if ([userKey isEqualToString:uncachedUser.key]) {
            XCTAssertNil(cachedUsers[userKey]);     //Make sure the uncached user is still uncached.
        } else {
            XCTAssertNotNil(cachedUsers[userKey]);  //Make sure other users have not been affected
        }
    }
}

-(void)testSaveAndFindUserWithKey {
    //Save, then find several users, up to the kUserCacheSize, to make sure users are saved and retrieved correctly
    self.config.secondaryMobileKeys = [LDConfig secondaryMobileKeysStub];
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys mobileKeys:self.config.mobileKeys];
    //A dataManager works in only one environment
    NSMutableDictionary<NSString*, LDDataManager*> *dataManagers = [NSMutableDictionary dictionaryWithCapacity:self.config.mobileKeys.count];
    for (NSString *mobileKey in self.config.mobileKeys) {
        dataManagers[mobileKey] = [LDDataManager dataManagerWithMobileKey:mobileKey config:self.config];
    }
    NSMutableArray<XCTestExpectation*> *saveUserExpectations = [NSMutableArray arrayWithCapacity:kUserCacheSize * userEnvironments.count];

    for (NSString *userKey in userKeys) {
        LDUserEnvironment *userEnvironment = userEnvironments[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation.%@.%@",
                                                                                       NSStringFromSelector(_cmd), userKey, mobileKey]];
            [saveUserExpectations addObject:saveUserExpectation];
            LDUserModel *userInEnvironment = [userEnvironment userForMobileKey:mobileKey];
            LDDataManager *dataManager = dataManagers[mobileKey];
            [dataManager saveEnvironmentForUser:userInEnvironment completion:^{
                [saveUserExpectation fulfill];
            }];
        }
    }
    [self waitForExpectations: saveUserExpectations timeout:1.0];

    for (NSString *userKey in userKeys) {
        LDUserEnvironment *userEnvironment = userEnvironments[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            LDUserModel *originalUserInEnvironment = [userEnvironment userForMobileKey:mobileKey];
            LDDataManager *dataManager = dataManagers[mobileKey];
            LDUserModel *retrievedUserInEnvironment = [dataManager findUserWithKey:userKey];

            XCTAssertTrue([retrievedUserInEnvironment isEqual:originalUserInEnvironment ignoringAttributes:@[kUserAttributeUpdatedAt]]);
        }
    }
}

-(void)testSaveAndFindUserWithKey_singleUser_singleEnvironment {
    XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation", NSStringFromSelector(_cmd)]];

    [self.dataManager saveEnvironmentForUser:self.user completion:^{
        [saveUserExpectation fulfill];
    }];
    [self waitForExpectations:@[saveUserExpectation] timeout:1.0];
    LDUserModel *retrievedUser = [self.dataManager findUserWithKey:self.user.key];

    XCTAssertTrue([retrievedUser isEqual:self.user ignoringAttributes:@[kUserAttributeUpdatedAt]]);
}

-(void)testSaveAndFindUserWithKey_noStoredUserEnvironments {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDefaultsKeyUserEnvironments];
    XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation", NSStringFromSelector(_cmd)]];

    [self.dataManager saveEnvironmentForUser:self.user completion:^{
        [saveUserExpectation fulfill];
    }];
    [self waitForExpectations:@[saveUserExpectation] timeout:1.0];
    LDUserModel *retrievedUser = [self.dataManager findUserWithKey:self.user.key];

    XCTAssertTrue([retrievedUser isEqual:self.user ignoringAttributes:@[kUserAttributeUpdatedAt]]);
}

-(void)testSaveAndFindUserWithKey_userWithoutFlagConfig {
    [self.dataManager saveUser:self.user];
    LDFlagConfigModel *flagConfig = [[LDFlagConfigModel alloc] init];
    self.user.flagConfig = flagConfig;
    XCTestExpectation *userSavedExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.userSavedExpectation",NSStringFromSelector(_cmd)]];

    [self.dataManager saveEnvironmentForUser:self.user completion:^{
        [userSavedExpectation fulfill];
    }];
    [self waitForExpectations:@[userSavedExpectation] timeout:1.0];

    LDUserModel *foundUser = [self.dataManager findUserWithKey:self.user.key];
    XCTAssertTrue(foundUser.flagConfig.isEmpty);
}

- (void)testSaveAndFindUser_cachedUser {
    //Temporarily make the user's flagConfig empty
    LDFlagConfigModel *flagConfig = self.user.flagConfig;
    self.user.flagConfig = [[LDFlagConfigModel alloc] init];
    [self.dataManager saveUser:self.user];
    //Restore the flag config
    self.user.flagConfig = flagConfig;
    XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation", NSStringFromSelector(_cmd)]];

    [self.dataManager saveEnvironmentForUser:self.user completion:^{
        [saveUserExpectation fulfill];
    }];

    [self waitForExpectations:@[saveUserExpectation] timeout:1.0];
    LDUserModel *retrievedUser = [self.dataManager findUserWithKey:self.user.key];
    XCTAssertTrue([retrievedUser isEqual:self.user ignoringAttributes:@[@"updatedAt"]]);
}

-(void)testSaveAndFindUsers_overCapacity {
    //Save more users than the cache should hold, and verify the cache retains only the newest users
    self.config.secondaryMobileKeys = [LDConfig secondaryMobileKeysStub];
    NSUInteger userCount = kUserCacheSize + 3;
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:userCount];
    NSMutableDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [NSMutableDictionary dictionaryWithCapacity:userCount];
    NSMutableDictionary<NSString*, LDDataManager*> *dataManagers = [NSMutableDictionary dictionaryWithCapacity:self.config.mobileKeys.count];
    for (NSString *mobileKey in self.config.mobileKeys) {
        dataManagers[mobileKey] = [LDDataManager dataManagerWithMobileKey:mobileKey config:self.config];
    }
    NSMutableArray<XCTestExpectation*> *saveUserExpectations = [NSMutableArray arrayWithCapacity:self.config.mobileKeys.count];

    //Save each user, 1 at a time, in reverse order. That way the oldest users have the highest indices, making it easier to assert later
    for (NSInteger index = userCount - 1; index >= 0; index--) {
        NSString *userKey = userKeys[index];
        NSDictionary<NSString*, LDUserModel*> *userModels = [LDUserEnvironment stubUserModelsForUserWithKey:userKey environmentKeys:self.config.mobileKeys];
        LDUserEnvironment *userEnvironment = [LDUserEnvironment userEnvironmentForUserWithKey:userKey environments:userModels];
        userEnvironments[userKey] = userEnvironment;
        for (NSString *mobileKey in self.config.mobileKeys) {
            XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation.%@.%@",
                                                                                       NSStringFromSelector(_cmd), userKey, mobileKey]];
            [saveUserExpectations addObject:saveUserExpectation];
            [dataManagers[mobileKey] saveEnvironmentForUser:userModels[mobileKey] completion:^{
                [saveUserExpectation fulfill];
            }];
        }
        //Force each user to save all environments before proceeding. Otherwise newer users could be corrupted by an older user's save block that the system delayed.
        //This fits the operational use for saving also...the SDK doesn't save multiple user's at once, rather they are saved one at a time.
        [self waitForExpectations: saveUserExpectations timeout:1.0];
        [saveUserExpectations removeAllObjects];
    }

    for (NSInteger index = 0; index < userCount; index++) {
        NSString *userKey = userKeys[index];
        LDUserEnvironment *userEnvironment = userEnvironments[userKey];
        for (NSString *mobileKey in self.config.mobileKeys) {
            LDUserModel *retrievedUserInEnvironment = [dataManagers[mobileKey] findUserWithKey:userKey];

            if (index < kUserCacheSize) {
                //Newest users (indices 0..<kUserCacheSize) should have matching environments in the cache
                LDUserModel *originalUserInEnvironment = [userEnvironment userForMobileKey:mobileKey];
                XCTAssertTrue([retrievedUserInEnvironment isEqual:originalUserInEnvironment ignoringAttributes:@[kUserAttributeUpdatedAt]]);
            } else {
                //Older users (indices kUserCacheSize..<userCount) should have been purged by the newer users.
                XCTAssertNil(retrievedUserInEnvironment);
            }
        }
    }
}

-(void)testSaveAndFindUser_withPrivateAttributes {
    //This is here to document this behavior: a user's privateAttributes array is not saved to the cache, and so not restored. Note that this is specific to user.privateAttributes, not the attributes themselves.
    self.user.privateAttributes = [LDUserModel allUserAttributes];
    XCTestExpectation *userSavedExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.userSavedExpectation", NSStringFromSelector(_cmd)]];

    [self.dataManager saveEnvironmentForUser:self.user completion:^{
        [userSavedExpectation fulfill];
    }];
    [self waitForExpectations:@[userSavedExpectation] timeout:1.0];
    LDUserModel *foundUser = [self.dataManager findUserWithKey:self.user.key];

    XCTAssertNotNil(foundUser);
    NSArray *ignoredAttributes = @[kUserAttributeUpdatedAt, kUserAttributePrivateAttributes];
    XCTAssertTrue([foundUser isEqual:self.user ignoringAttributes:ignoredAttributes]);
    XCTAssertNil(foundUser.privateAttributes);  //privateAttributes isn't restored, even though it was present in self.user.
}

-(void)testSaveAndFindUser_multipleManagers {
    //Sets up multiple dataManagers, each with its own save queue. Sets each DM to save after the fireTime, hoping to force them to wait for each other. If they don't a user will be corrupted.
    //NOTE: There is some non-deterministic behavior in this test because there's no guarantee that the saveUser calls will actually fire at the same time and force the @synchronized to wait. However, when this test was run without the @synchronized in saveUser, it failed 5 of 5 times.
    NSUInteger dataManagerCount = kUserCacheSize;   //Any more users will start pushing users out of the cache
    NSMutableArray<XCTestExpectation*> *userSavedExpectations = [NSMutableArray arrayWithCapacity:dataManagerCount];
    NSMutableDictionary<NSString*, LDDataManager*> *dataManagers = [NSMutableDictionary dictionaryWithCapacity:dataManagerCount];
    NSMutableDictionary<NSString*, LDUserModel*> *users = [NSMutableDictionary dictionaryWithCapacity:dataManagerCount];
    dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, 40000);     //40ms from now, arbitrary but seems enough time to setup without delaying the test
    for (NSUInteger index = 0; index < dataManagerCount; index++) {
        NSString *key = [[NSUUID UUID] UUIDString];
        LDDataManager *dataManager = [LDDataManager dataManagerWithMobileKey:key config:self.config];
        dataManagers[key] = dataManager;
        XCTestExpectation *userSavedExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.userSavedExpectation.%@", NSStringFromSelector(_cmd), key]];
        [userSavedExpectations addObject:userSavedExpectation];
        LDUserModel *user = [LDUserModel stubWithKey:key];
        users[key] = user;
        dispatch_queue_t dispatchQueue = dispatch_queue_create([key UTF8String], DISPATCH_QUEUE_SERIAL);

        dispatch_after(fireTime, dispatchQueue, ^{
            [dataManager saveEnvironmentForUser:user completion:^{
                [userSavedExpectation fulfill];
            }];
        });
    }

    [self waitForExpectations:userSavedExpectations timeout:1.0];

    for (NSString *key in users.allKeys) {
        LDUserModel *targetUser = users[key];
        LDDataManager *dataManager = dataManagers[key];
        LDUserModel *retrievedUser = [dataManager findUserWithKey:key];
        XCTAssertTrue([retrievedUser isEqual:targetUser ignoringAttributes:@[kUserAttributeUpdatedAt]]);
    }
}

-(void)testSaveUserWithKey_noUserKey {
    XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation", NSStringFromSelector(_cmd)]];
    LDUserModel *userWithoutKey = [LDUserModel stubWithKey:nil];
    userWithoutKey.key = nil;

    [self.dataManager saveEnvironmentForUser:userWithoutKey completion:^{
        [saveUserExpectation fulfill];
    }];
    [self waitForExpectations:@[saveUserExpectation] timeout:1.0];

    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDDataManager retrieveUserEnvironments];
    XCTAssertTrue(userEnvironments.count == 0);
}

-(void)testSaveUser_missingUser {
    XCTestExpectation *userSaveExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.userSaveExpectation", NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];

    LDUserModel *missingUser;

    [self.dataManager saveEnvironmentForUser:missingUser completion:^{
        [userSaveExpectation fulfill];
    }];
    [self waitForExpectations:@[userSaveExpectation] timeout:1.0];

    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDDataManager retrieveUserEnvironments];
    XCTAssertTrue(userEnvironments.count == 0);
}

-(void)testFindUser_missingUserKey {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys];
    [LDDataManager saveUserEnvironments:userEnvironments];
    NSString *missingUserKey;

    LDUserModel *foundUser = [self.dataManager findUserWithKey:missingUserKey];

    XCTAssertNil(foundUser);
}

-(void)testFindUser_emptyUserKey {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys];
    [LDDataManager saveUserEnvironments:userEnvironments];

    LDUserModel *foundUser = [self.dataManager findUserWithKey:@""];

    XCTAssertNil(foundUser);
}

-(void)testRetrieveFlagConfigForUser {
    XCTestExpectation *saveUserExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"LDDataManagerTest.%@.saveUserExpectation", NSStringFromSelector(_cmd)]];
    [self.dataManager saveEnvironmentForUser:self.user completion:^{
        [saveUserExpectation fulfill];
    }];
    LDUserBuilder *userBuilder = [LDUserBuilder currentBuilder:self.user];
    LDUserModel *restoredUser = [userBuilder build];
    [self waitForExpectations:@[saveUserExpectation] timeout:1.0];

    LDFlagConfigModel *flagConfig = [self.dataManager retrieveFlagConfigForUser:restoredUser];

    XCTAssertTrue([flagConfig isEqualToConfig:self.user.flagConfig]);
}

-(void)testRetrieveFlagConfigForUser_userNotCached {
    LDUserBuilder *userBuilder = [LDUserBuilder currentBuilder:self.user];
    LDUserModel *restoredUser = [userBuilder build];

    restoredUser.flagConfig = [self.dataManager retrieveFlagConfigForUser:restoredUser];

    NSArray *ignoredAttributes = @[kUserAttributeUpdatedAt, kUserAttributeConfig];
    XCTAssertTrue([restoredUser isEqual:self.user ignoringAttributes:ignoredAttributes]);
    XCTAssertTrue(restoredUser.flagConfig.isEmpty);
}

-(void)testRetrieveFlagConfigForUser_userNotCached_missingFlagConfig {
    LDUserModel *userWithoutFlagConfig = [self.user copy];
    userWithoutFlagConfig.flagConfig = nil;

    LDFlagConfigModel *flagConfig = [self.dataManager retrieveFlagConfigForUser:userWithoutFlagConfig];

    XCTAssertNotNil(flagConfig);
    XCTAssertTrue([flagConfig isEmpty]);
    XCTAssertFalse([flagConfig isEqualToConfig:self.user.flagConfig]);
}

-(void)testRetrieveFlagConfigForUser_missingUser {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserEnvironment*> *userEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys];
    [LDDataManager saveUserEnvironments:userEnvironments];
    LDUserModel *missingUser;

    LDFlagConfigModel *flagConfig = [self.dataManager retrieveFlagConfigForUser:missingUser];

    XCTAssertTrue(flagConfig.isEmpty);
}

-(void)testSaveAndRetrieveUserEnvironments {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize];
    NSDictionary<NSString*, LDUserEnvironment*> *originalUserEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys];

    [self.dataManager saveUserEnvironments:originalUserEnvironments];
    NSDictionary<NSString*, LDUserEnvironment*> *retrievedUserEnvironments = [self.dataManager retrieveUserEnvironments];

    XCTAssertEqual(retrievedUserEnvironments.count, kUserCacheSize);
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *originalUserEnvironment = originalUserEnvironments[userKey];
        LDUserEnvironment *retrievedUserEnvironment = retrievedUserEnvironments[userKey];
        XCTAssertTrue([retrievedUserEnvironment isEqualToUserEnvironment:originalUserEnvironment]);
    }
}

-(void)testSaveUserEnvironments_invalidEnvironment {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize - 1];
    NSMutableDictionary *originalUserEnvironments = [NSMutableDictionary dictionaryWithDictionary:[LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys]];
    NSString *invalidEnvironmentKey = [[NSUUID UUID] UUIDString];
    originalUserEnvironments[invalidEnvironmentKey] = @"Bad Environment";

    [self.dataManager saveUserEnvironments:originalUserEnvironments];

    NSDictionary<NSString*, LDUserEnvironment*> *retrievedUserEnvironments = [self.dataManager retrieveUserEnvironments];
    XCTAssertNil(retrievedUserEnvironments[invalidEnvironmentKey]);
    XCTAssertEqual(retrievedUserEnvironments.count, kUserCacheSize - 1);
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *originalUserEnvironment = originalUserEnvironments[userKey];
        LDUserEnvironment *retrievedUserEnvironment = retrievedUserEnvironments[userKey];
        XCTAssertTrue([retrievedUserEnvironment isEqualToUserEnvironment:originalUserEnvironment]);
    }
}

-(void)testRetrieveUserEnvironments_invalidEnvironmentDictionary {
    NSArray<NSString*> *userKeys = [LDUserModel stubUserKeysWithCount:kUserCacheSize - 1];
    NSDictionary<NSString*, LDUserEnvironment*> *originalUserEnvironments = [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys];
    [self.dataManager saveUserEnvironments:originalUserEnvironments];
    NSString *invalidEnvironmentDictionaryKey = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *userEnvironmentDictionaries = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsKeyUserEnvironments]];
    userEnvironmentDictionaries[invalidEnvironmentDictionaryKey] = @"Bad Environment Dictionary";
    [[NSUserDefaults standardUserDefaults] setObject:[userEnvironmentDictionaries copy] forKey:kUserDefaultsKeyUserEnvironments];

    NSDictionary<NSString*, LDUserEnvironment*> *retrievedUserEnvironments = [self.dataManager retrieveUserEnvironments];

    XCTAssertEqual(retrievedUserEnvironments.count, kUserCacheSize - 1);
    XCTAssertNil(retrievedUserEnvironments[invalidEnvironmentDictionaryKey]);
    for (NSString *userKey in userKeys) {
        LDUserEnvironment *originalUserEnvironment = originalUserEnvironments[userKey];
        LDUserEnvironment *retrievedUserEnvironment = retrievedUserEnvironments[userKey];
        XCTAssertTrue([retrievedUserEnvironment isEqualToUserEnvironment:originalUserEnvironment]);
    }
}

-(void)testRecordFlagEvaluationEvents {
    id trackerMock = OCMClassMock([LDFlagConfigTracker class]);
    self.user = [LDUserModel stubWithKey:nil usingTracker:trackerMock eventTrackingContext:nil];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            [self.dataManager discardEventsDictionary];

            XCTestExpectation *eventsExpectation = [self expectationWithDescription:@"LDDataManagerTest.testRecordFlagEvaluationEvents.allEvents"];
            [[trackerMock expect] logRequestForFlagKey:flagKey reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultValue:defaultFlagValue];

            [self.dataManager recordFlagEvaluationEventsWithFlagKey:flagKey
                                                               reportedFlagValue:flagConfigValue.value
                                                                 flagConfigValue:flagConfigValue
                                                                defaultFlagValue:defaultFlagValue
                                                                            user:self.user];

            [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
                XCTAssertEqual(eventDictionaries.count, 2);
                for (NSString *eventKind in @[kEventModelKindFeature, kEventModelKindDebug]) {
                    NSPredicate *eventPredicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                        if (![evaluatedObject isKindOfClass:[NSDictionary class]]) { return NO; }
                        NSDictionary *evaluatedDictionary = evaluatedObject;
                        return [evaluatedDictionary[kEventModelKeyKind] isEqualToString:eventKind] && [evaluatedDictionary[kEventModelKeyKey] isEqualToString:flagKey];
                    }];
                    XCTAssertEqual([eventDictionaries filteredArrayUsingPredicate:eventPredicate].count, 1);
                }
                [eventsExpectation fulfill];
            }];
            [trackerMock verify];
            [self waitForExpectations:@[eventsExpectation] timeout:1.0];
        }
    }
}

-(void)testRecordSummaryEvent {
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    LDFlagConfigTracker *tracker = self.user.flagConfigTracker;
    LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:self.user.flagConfigTracker];

    [self.dataManager recordSummaryEventAndResetTrackerForUser:self.user];

    __block NSDictionary *eventDictionary;
    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqual(eventDictionaries.count, 1);
        if (eventDictionaries.count == 1) {
            eventDictionary = [eventDictionaries firstObject];
        }
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
    XCTAssertNotNil(self.user.flagConfigTracker);
    XCTAssertTrue(self.user.flagConfigTracker != tracker);      //different pointers
    XCTAssertFalse(self.user.flagConfigTracker.hasTrackedEvents);
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyStartDate], @(summaryEvent.startDateMillis));
    XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyEndDate] ldMillisecondValue], summaryEvent.endDateMillis, 10));
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyFeatures], summaryEvent.flagRequestSummary);
}

-(void)testRecordSummaryEvent_noCounters {
    self.user.flagConfigTracker = [LDFlagConfigTracker tracker];
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];

    [self.dataManager recordSummaryEventAndResetTrackerForUser:self.user];

    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqual(eventDictionaries.count, 0);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

-(void)testRecordSummaryEvent_nilTracker {
    self.user.flagConfigTracker = nil;
    XCTestExpectation *expectation = [self expectationWithDescription:@"LDDataManagerTest.testRecordSummaryEvent_nilTracker.allEvents"];

    [self.dataManager recordSummaryEventAndResetTrackerForUser:self.user];

    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqual(eventDictionaries.count, 0);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

-(void)testRecordSummaryEvent_multipleThreads {
    dispatch_queue_t firstQueue = dispatch_queue_create("com.launchdarkly.test.dataManager.recordSummaryEvent.multipleThreads.one", DISPATCH_QUEUE_SERIAL);
    XCTestExpectation *firstQueueFiredExpectation = [self expectationWithDescription:@"firstQueueFiredExpectation"];
    dispatch_queue_t secondQueue = dispatch_queue_create("com.launchdarkly.test.dataManager.recordSummaryEvent.multipleThreads.two", DISPATCH_QUEUE_SERIAL);
    XCTestExpectation *secondQueueFiredExpectation = [self expectationWithDescription:@"secondQueueFiredExpectation"];
    dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, 1000);  //one millisecond later
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    LDFlagConfigTracker *tracker = self.user.flagConfigTracker;
    LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:self.user.flagConfigTracker];
    __weak typeof(self) weakSelf = self;

    dispatch_after(fireTime, firstQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.dataManager recordSummaryEventAndResetTrackerForUser:self.user];
        [firstQueueFiredExpectation fulfill];
    });
    dispatch_after(fireTime, secondQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.dataManager recordSummaryEventAndResetTrackerForUser:self.user];
        [secondQueueFiredExpectation fulfill];
    });

    [self waitForExpectations:@[firstQueueFiredExpectation, secondQueueFiredExpectation] timeout:1.0];
    __block NSDictionary *eventDictionary;
    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqual(eventDictionaries.count, 1);
        if (eventDictionaries.count == 1) {
            eventDictionary = [eventDictionaries firstObject];
        }
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
    XCTAssertNotNil(self.user.flagConfigTracker);
    XCTAssertTrue(self.user.flagConfigTracker != tracker);      //different pointers
    XCTAssertFalse(self.user.flagConfigTracker.hasTrackedEvents);
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyStartDate], @(summaryEvent.startDateMillis));
    XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyEndDate] ldMillisecondValue], summaryEvent.endDateMillis, 10));
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyFeatures], summaryEvent.flagRequestSummary);
}

-(void)testRecordFeatureEvent_trackEvents_YES {
    LDFlagConfigValue *flagConfigValue = [self setupCreateFeatureEventTestWithTrackEvents:YES];
    [[self.eventModelMock expect] featureEventWithFlagKey:kFlagKeyIsABawler
                                        reportedFlagValue:flagConfigValue.value
                                          flagConfigValue:flagConfigValue
                                         defaultFlagValue:@(NO)
                                                     user:self.user
                                               inlineUser:NO];

    [self.dataManager recordFeatureEventWithFlagKey:kFlagKeyIsABawler
                                               reportedFlagValue:flagConfigValue.value
                                                 flagConfigValue:flagConfigValue
                                                defaultFlagValue:@(NO)
                                                            user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordFeatureEvent_trackEvents_NO {
    LDFlagConfigValue *flagConfigValue = [self setupCreateFeatureEventTestWithTrackEvents:NO];
    [[self.eventModelMock reject] featureEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any] inlineUser:[OCMArg any]];

    [self.dataManager recordFeatureEventWithFlagKey:kFlagKeyIsABawler
                                               reportedFlagValue:flagConfigValue.value
                                                 flagConfigValue:flagConfigValue
                                                defaultFlagValue:@(NO)
                                                            user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordFeatureEvent_eventTrackingContext_nil {
    LDFlagConfigValue *flagConfigValue = [self setupCreateFeatureEventTestWithTrackEvents:YES includeTrackingContext:NO];
    [[self.eventModelMock reject] featureEventWithFlagKey:[OCMArg any]
                                        reportedFlagValue:[OCMArg any]
                                          flagConfigValue:[OCMArg any]
                                         defaultFlagValue:[OCMArg any]
                                                     user:[OCMArg any]
                                               inlineUser:[OCMArg any]];

    [self.dataManager recordFeatureEventWithFlagKey:kFlagKeyIsABawler
                                               reportedFlagValue:flagConfigValue.value
                                                 flagConfigValue:flagConfigValue
                                                defaultFlagValue:@(NO)
                                                            user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_lastEventResponseDate_systemDate_debugEventsUntilDate_createEvent {
    //lastEventResponseDate < systemDate < debugEventsUntilDate         create event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [[self.eventModelMock expect] debugEventWithFlagKey:kFlagKeyIsABawler reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultFlagValue:@(NO) user:self.user];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_systemDate_lastEventResponseDate_debugEventsUntilDate_createEvent {
    //systemDate < lastEventResponseDate < debugEventsUntilDate         create event        //system time not right, set too far in the past, but lastEventResponse hasn't reached debug
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [[self.eventModelMock expect] debugEventWithFlagKey:kFlagKeyIsABawler reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultFlagValue:@(NO) user:self.user];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_lastEventResponseDate_debugEventsUntilDate_systemDate_dontCreateEvent {
    //lastEventResponseDate < debugEventsUntilDate < systemDate         no event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:[NSDate date]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_debugEventsUntilDate_lastEventResponseDate_systemDate_dontCreateEvent {
    //debugEventsUntilDate < lastEventResponseDate < systemDate         no event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:-2.0]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_debugEventsUntilDate_systemDate_lastEventResponseDate_dontCreateEvent {
    //debugEventsUntilDate < systemDate < lastEventResponseDate         no event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:-1.0]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_systemDate_debugEventsUntilDate_lastEventResponseDate_dontCreateEvent {
    //systemDate < debugEventsUntilDate < lastEventResponseDate         no event            //system time not right, set too far in the past, lastEventResponse past debug
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:2.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_missingDebugEventsUntilDate_dontCreateEvent {
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:nil];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testRecordDebugEvent_missingEventTrackingContext_dontCreateEvent {
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:nil includeTrackingContext:NO];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [self.dataManager recordDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user];

    [self.eventModelMock verify];
}

-(void)testAllEventsDictionaryArray {
    LDEventModel *featureEvent = [LDEventModel stubEventWithKind:kEventModelKindFeature user:self.user config:self.config];
    [self.dataManager recordFeatureEventWithFlagKey:featureEvent.key
                                               reportedFlagValue:featureEvent.reportedValue
                                                 flagConfigValue:featureEvent.flagConfigValue
                                                defaultFlagValue:featureEvent.defaultValue
                                                            user:self.user];
    LDEventModel *customEvent = [LDEventModel stubEventWithKind:kEventModelKindCustom user:self.user config:self.config];
    [self.dataManager recordCustomEventWithKey:customEvent.key customData:customEvent.data user:self.user];
    LDEventModel *identifyEvent = [LDEventModel stubEventWithKind:kEventModelKindIdentify user:self.user config:self.config];
    [self.dataManager recordIdentifyEventWithUser:self.user];
    LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:self.user.flagConfigTracker];
    [self.dataManager recordSummaryEventAndResetTrackerForUser:self.user];
    LDEventModel *debugEvent = [LDEventModel stubEventWithKind:kEventModelKindDebug user:self.user config:self.config];
    [self.dataManager recordDebugEventWithFlagKey:debugEvent.key
                                             reportedFlagValue:debugEvent.reportedValue
                                               flagConfigValue:debugEvent.flagConfigValue
                                              defaultFlagValue:debugEvent.defaultValue
                                                          user:self.user];
    NSArray<LDEventModel*> *eventStubs = @[featureEvent, customEvent, identifyEvent, summaryEvent, debugEvent];

    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    
    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        for (LDEventModel *event in eventStubs) {
            NSDictionary *eventDictionary = [eventDictionaries dictionaryForEvent:event];

            XCTAssertNotNil(eventDictionary);
            if (!eventDictionary) {
                NSLog(@"Did not find matching event dictionary for event: %@", event.kind);
                continue;
            }

            XCTAssertEqualObjects(eventDictionary[kEventModelKeyKind], event.kind);
            if (event.hasCommonFields) {
                XCTAssertEqualObjects(eventDictionary[kEventModelKeyKey], event.key);
                if (event.alwaysInlinesUser) {
                    XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
                } else {
                    XCTAssertEqualObjects(eventDictionary[kEventModelKeyUserKey], event.user.key);
                }
                XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
                XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyCreationDate] ldMillisecondValue], event.creationDate, 1));
            }
            if (event.isFlagRequestEventKind) {
                XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyValue], event.flagConfigValue.value);
                XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyVariation], @(event.flagConfigValue.variation));
                XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyVersion], event.flagConfigValue.flagVersion);
                XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyFlagVersion]);
                XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyTrackEvents]);
                XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
                XCTAssertEqualObjects(eventDictionary[kEventModelKeyDefault], event.defaultValue);
            }
            if ([event.kind isEqualToString:kEventModelKindCustom]) {
                XCTAssertEqualObjects(eventDictionary[kEventModelKeyData], event.data);
            }
            if ([event.kind isEqualToString:kEventModelKindFeatureSummary]) {
                XCTAssertEqualObjects(eventDictionary[kEventModelKeyStartDate], @(event.startDateMillis));
                XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyEndDate] ldMillisecondValue], event.endDateMillis, 10));
                XCTAssertEqualObjects(eventDictionary[kEventModelKeyFeatures], event.flagRequestSummary);
            }
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

-(void)testRecordEventAfterCapacityReached {
    self.config.capacity = @(2);
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    [self.dataManager.eventsArray removeAllObjects];
    [self.dataManager recordCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user];
    [self.dataManager recordCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user];
    [self.dataManager recordCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true"
                                                                                     flagKey:kLDFlagKeyIsABool
                                                                        eventTrackingContext:[LDEventTrackingContext stub]];
    [self.dataManager recordFeatureEventWithFlagKey: @"anotherKey"
                                  reportedFlagValue:flagConfigValue.value
                                    flagConfigValue:flagConfigValue
                                   defaultFlagValue:@(NO)
                                               user:self.user];

    [self.dataManager allEventDictionaries:^(NSArray *array) {
        XCTAssertEqual([array count],2);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

-(void)testDeleteProcessedEvents {
    NSArray<NSDictionary*> *events = [LDEventModel stubEventDictionariesForUser:self.user config:self.config];
    for (NSInteger processedCount = 0; processedCount <= events.count; processedCount++) {
        NSArray<NSDictionary*> *processedEvents = [events subarrayWithRange:NSMakeRange(0, processedCount)];
        NSArray<NSDictionary*> *unprocessedEvents = [events subarrayWithRange:NSMakeRange(processedCount, events.count - processedCount)];
        self.dataManager.eventsArray = [NSMutableArray arrayWithArray:events];

        [self.dataManager deleteProcessedEvents:processedEvents];   //asynchronous, but without a completion block

        XCTestExpectation *allEventDictionaryExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"testDeleteProcessedEvents-%ld events", processedCount]];
        [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
            XCTAssertEqualObjects(eventDictionaries, unprocessedEvents);
            [allEventDictionaryExpectation fulfill];
        }];
        [self waitForExpectations:@[allEventDictionaryExpectation] timeout:1.0];
    }
}

-(void)testDeleteProcessedEvents_nilProcessedJsonArray {
    NSArray<NSDictionary*> *events = [LDEventModel stubEventDictionariesForUser:self.user config:self.config];
    self.dataManager.eventsArray = [NSMutableArray arrayWithArray:events];

    [self.dataManager deleteProcessedEvents:nil];   //asynchronous, but without a completion block

    XCTestExpectation *allEventDictionaryExpectation = [self expectationWithDescription:@"testDeleteProcessedEvents_nilProcessedJsonArray"];
    [self.dataManager allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqualObjects(eventDictionaries, events);
        [allEventDictionaryExpectation fulfill];
    }];
    [self waitForExpectations:@[allEventDictionaryExpectation] timeout:1.0];
}
@end

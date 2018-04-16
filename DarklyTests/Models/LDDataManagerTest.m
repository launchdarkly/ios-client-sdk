//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDFlagConfigModel.h"
#import "LDDataManager.h"
#import "LDUserModel.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDEventModel.h"
#import "LDEventModel+Testable.h"
#import "LDEventModel+Equatable.h"
#import "LDClient.h"
#import "OCMock.h"
#import "NSArray+UnitTests.h"
#import "LDDataManager+Testable.h"

extern NSString * const kEventModelKeyKind;

@interface LDDataManagerTest : DarklyXCTestCase
@property (nonatomic) id clientMock;
@property (nonnull) LDUserModel *user;

@end

@implementation LDDataManagerTest
@synthesize clientMock;
@synthesize user;

- (void)setUp {
    [super setUp];
    user = [[LDUserModel alloc] init];
    user.key = [[NSUUID UUID] UUIDString];
    user.firstName = @"Bob";
    user.lastName = @"Giffy";
    user.email = @"bob@gmail.com";
    user.updatedAt = [NSDate date];
    
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldDataManagerTestConfig"];
    user.config = flagConfig;

    clientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([clientMock sharedInstance])).andReturn(clientMock);
    OCMStub([clientMock ldUser]).andReturn(user);
}

- (void)tearDown {
    [clientMock stopMocking];
    clientMock = nil;
    [[LDDataManager sharedManager] flushEventsDictionary];
    [super tearDown];
}

- (void)testisFlagOnForKey {
    LDClient *client = [LDClient sharedInstance];
    LDUserModel * theUser = client.ldUser;
    
    BOOL ipaduserFlag = [(NSNumber *)[theUser flagValue: @"ipaduser"] boolValue];
    BOOL iosuserFlag = [(NSNumber *)[theUser flagValue: @"iosuser"] boolValue];
    
    XCTAssertFalse(iosuserFlag);
    XCTAssertTrue(ipaduserFlag);
}

-(void)testAllEventsDictionaryArray {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"stubMobileKey"];
    LDEventModel *featureEvent = [LDEventModel stubEventWithKind:kEventModelKindFeature user:self.user config:config];
    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:featureEvent.key flagValue:featureEvent.value defaultFlagValue:featureEvent.defaultValue user:self.user config:config];
    LDEventModel *customEvent = [LDEventModel stubEventWithKind:kEventModelKindCustom user:self.user config:config];
    [[LDDataManager sharedManager] createCustomEventWithKey:customEvent.key customData:customEvent.data user:self.user config:config];
    LDEventModel *identifyEvent = [LDEventModel stubEventWithKind:kEventModelKindIdentify user:self.user config:config];
    [[LDDataManager sharedManager] createIdentifyEventWithUser:self.user config:config];
    NSArray<LDEventModel*> *eventStubs = @[featureEvent, customEvent, identifyEvent];

    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    
    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
        for (NSDictionary *eventDictionary in eventDictionaries) {
            NSPredicate *matchingEventPredicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                LDEventModel *evaluatedEvent = evaluatedObject;
                return [eventDictionary[kEventModelKeyKind] isEqualToString:evaluatedEvent.kind];
            }];
            LDEventModel *matchingEvent = [[eventStubs filteredArrayUsingPredicate:matchingEventPredicate] firstObject];

            XCTAssertNotNil(matchingEvent);
            if (!matchingEvent) { continue; }
            XCTAssertTrue([matchingEvent hasPropertiesMatchingDictionary:eventDictionary]);
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
    
}

-(void)testAllEventDictionaries {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"stubMobileKey"];
    [[LDDataManager sharedManager] createCustomEventWithKey:@"foo" customData:nil user:self.user config:config];
    [[LDDataManager sharedManager] createCustomEventWithKey:@"fi" customData:nil user:self.user config:config];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events json data expectation"];
    
    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
        
        NSMutableDictionary *events = [[NSMutableDictionary alloc] init];
        for (NSDictionary *eventDictionary in eventDictionaries) {
            XCTAssertTrue([eventDictionary[@"userKey"] isEqualToString:self.user.key]);
            [events setObject:[[LDEventModel alloc] initWithDictionary:eventDictionary] forKey:[eventDictionary objectForKey:@"key"]];
        }
        
        XCTAssertEqual([events count], 2);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:10];
    
}


-(void)testFindOrCreateUser {
    NSString *userKey = @"thisisgus";
    LDUserModel *aUser = [[LDUserModel alloc] init];
    aUser.key = userKey;
    aUser.email = @"gus@anemail.com";
    aUser.updatedAt = [NSDate date];
    aUser.config = user.config;
    [[LDDataManager sharedManager] saveUser: aUser];
    
    LDUserModel *foundAgainUser = [[LDDataManager sharedManager] findUserWithkey: userKey];
    
    XCTAssertNotNil(foundAgainUser);
    XCTAssertEqualObjects(aUser.email, foundAgainUser.email);
}

-(void) testPurgeUsers {
    NSString *baseUserKey = @"gus";
    NSString *baseUserEmail = @"gus@email.com";
    
    for(int index = 0; index < kUserCacheSize + 3; index++) {
        LDUserModel *aUser = [[LDUserModel alloc] init];
        aUser.key = [NSString stringWithFormat: @"%@%d", baseUserKey, index];
        aUser.email = [NSString stringWithFormat: @"%@%d", baseUserEmail, index];;
        
        NSTimeInterval secondsInXHours = (index+1) * 60 * 60 * 24;
        NSDate *dateInXHours = [[NSDate date] dateByAddingTimeInterval:secondsInXHours];
        aUser.updatedAt = dateInXHours;
        
        [[LDDataManager sharedManager] saveUser: aUser];
    }
    
    XCTAssertEqual([[[LDDataManager sharedManager] retrieveUserDictionary] count],kUserCacheSize);
    NSString *firstCreatedKey = [NSString stringWithFormat: @"%@%d", baseUserKey, 0];
    LDUserModel *firstCreatedUser = [[LDDataManager sharedManager] findUserWithkey:firstCreatedKey];
    XCTAssertNil(firstCreatedUser);
    NSString *secondCreatedKey = [NSString stringWithFormat: @"%@%d", baseUserKey, 1];
    LDUserModel *secondCreatedUser = [[LDDataManager sharedManager] findUserWithkey:secondCreatedKey];
    XCTAssertNil(secondCreatedUser);
    NSString *thirdCreatedKey = [NSString stringWithFormat: @"%@%d", baseUserKey, 2];
    LDUserModel *thirdCreatedUser = [[LDDataManager sharedManager] findUserWithkey:thirdCreatedKey];
    XCTAssertNil(thirdCreatedUser);
    NSString *fourthCreatedKey = [NSString stringWithFormat: @"%@%d", baseUserKey, 3];
    LDUserModel *fourthCreatedUser = [[LDDataManager sharedManager] findUserWithkey:fourthCreatedKey];
    XCTAssertNotNil(fourthCreatedUser);
}

-(void)testCreateEventAfterCapacityReached {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"AMobileKey"];
    config.capacity = [NSNumber numberWithInt:2];

    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    OCMStub([clientMock ldConfig]).andReturn(config);
    
    LDDataManager *manager = [LDDataManager sharedManager];
    [manager.eventsArray removeAllObjects];
    
    [manager createCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user config:config];
    [manager createCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user config:config];
    [manager createCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user config:config];
    [manager createFeatureEventWithFlagKey: @"anotherKet" flagValue: [NSNumber numberWithBool:YES] defaultFlagValue: [NSNumber numberWithBool:NO] user:self.user config:config];
    
    [manager allEventDictionaries:^(NSArray *array) {
        XCTAssertEqual([array count],2);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:10];
}

@end

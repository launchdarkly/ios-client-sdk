//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDFlagConfigModel.h"
#import "LDDataManager.h"
#import "LDUserModel.h"
#import "LDFlagConfigModel.h"
#import "LDEventModel.h"
#import "LDClient.h"
#import <OCMock.h>
#import "NSArray+UnitTests.h"

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
    user.firstName = @"Bob";
    user.lastName = @"Giffy";
    user.email = @"bob@gmail.com";
    user.updatedAt = [NSDate date];
    
    
    LDClient *client = [LDClient sharedInstance];
    clientMock = OCMPartialMock(client);
    OCMStub([clientMock ldUser]).andReturn(user);
    
    LDFlagConfigModel *config = [[LDFlagConfigModel alloc] init];
    config.featuresJsonDictionary = [NSDictionary dictionaryWithObjects:@[@{@"value": @YES}, @{@"value": @NO}]
                                                                forKeys: @[@"ipaduser", @"iosuser"]];
    user.config = config;
}

- (void)tearDown {
    [clientMock stopMocking];
    [super tearDown];
}

- (void)testisFlagOnForKey {
    LDClient *client = [LDClient sharedInstance];
    LDUserModel * theUser = client.ldUser;
    
    BOOL ipaduserFlag = [theUser isFlagOn: @"ipaduser"];
    BOOL iosuserFlag = [theUser isFlagOn: @"iosuser"];
    
    XCTAssertFalse(iosuserFlag);
    XCTAssertTrue(ipaduserFlag);
}

-(void)testAllEventsDictionaryArray {
    NSString *eventKey1 = @"foo";
    NSString *eventKey2 = @"fi";
    [[LDDataManager sharedManager] createFeatureEvent:eventKey1 keyValue:NO defaultKeyValue:NO];
    [[LDDataManager sharedManager] createCustomEvent:eventKey2 withCustomValuesDictionary:@{@"carrot": @"cake"}];
    
    NSArray *eventArray = [[LDDataManager sharedManager] allEventsDictionaryArray];
    NSMutableArray *eventKeyArray = [[NSMutableArray alloc] init];
    for (NSDictionary *eventDictionary in eventArray) {
        [eventKeyArray addObject:[eventDictionary objectForKey:@"key"]];
    }

    XCTAssertTrue([eventKeyArray containsObject:eventKey1]);
    XCTAssertTrue([eventKeyArray containsObject:eventKey2]);
}

-(void)testAllEventsJsonData {
    [[LDDataManager sharedManager] createCustomEvent:@"foo" withCustomValuesDictionary:nil];
    [[LDDataManager sharedManager] createCustomEvent:@"fi" withCustomValuesDictionary:nil];
    
    NSData *eventData = [[LDDataManager sharedManager] allEventsJsonData];
    
    NSArray *eventsArray = [NSJSONSerialization JSONObjectWithData:eventData options:kNilOptions error:nil];

    NSMutableDictionary *eventDictionary = [[NSMutableDictionary alloc] init];
    for (NSDictionary *currentEventDictionary in eventsArray) {
        [eventDictionary setObject:[[LDEventModel alloc] initWithDictionary:currentEventDictionary] forKey:[currentEventDictionary objectForKey:@"key"]];
    }
    
    XCTAssertEqual([eventDictionary count], 2);
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

-(void)testCreateEventAfterCapacityReached{
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    builder = [builder withCapacity: 2];
    builder = [builder withApiKey: @"AnApiKey"];
    LDConfig *config = [builder build];
    
    OCMStub([clientMock ldConfig]).andReturn(config);
    
    [[LDDataManager sharedManager] createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [[LDDataManager sharedManager] createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [[LDDataManager sharedManager] createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [[LDDataManager sharedManager] createFeatureEvent: @"anotherKet" keyValue: YES defaultKeyValue: NO];
    
    XCTAssertEqual([[[LDDataManager sharedManager] retrieveEventDictionary] count],2);
}

@end

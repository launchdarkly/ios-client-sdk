//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import <BlocksKit/BlocksKit.h>
#import "LDFlagConfigModel.h"
#import <Blockskit/BlocksKit.h>
#import "LDFeatureFlagModel.h"
#import "LDDataManager.h"
#import "LDUserModel.h"
#import "LDFlagConfigModel.h"
#import "LDEventModel.h"
#import "LDClient.h"
#import <OCMock.h>
#import "NSArray+UnitTests.h"

@interface DataManagerTest : DarklyXCTestCase
@property (nonatomic) id clientMock;
@property (nonnull) LDUserModel *user;

@end

@implementation DataManagerTest
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
    OCMStub([clientMock user]).andReturn(user);
    
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
    LDUserModel * theUser = client.user;
    
    BOOL ipaduserFlag = [theUser isFlagOn: @"ipaduser"];
    BOOL iosuserFlag = [theUser isFlagOn: @"iosuser"];
    
    XCTAssertFalse(iosuserFlag);
    XCTAssertTrue(ipaduserFlag);
    
    NSLog(@"Stop");
}

-(void)testCreateFeatureEvent {
    [[LDDataManager sharedManager] createFeatureEvent:@"afeaturekey" keyValue:NO defaultKeyValue:NO];
    
//    TODO: Write test
    
//    XCTAssertEqualObjects(lastEvent.key, @"afeaturekey");
}

-(void)testAllEvents {
    LDEventModel *event1 = [[LDEventModel alloc] init];
    LDEventModel *event2 = [[LDEventModel alloc] init];
    
    event1.key = @"foo";
    event2.key = @"fi";
    
    
    NSArray *eventArray = [self.dataManagerMock allEvents];
    NSArray *eventKeys = [eventArray bk_map:^id(LDEventModel *event) {
        return event.key;
    }];
    XCTAssertTrue([eventKeys containsObject:event1.key]);
    XCTAssertTrue([eventKeys containsObject:event2.key]);
}

-(void)testCreateCustomEvent {
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    
    LDEventModel *event = [self.dataManagerMock allEvents].firstObject;

    XCTAssertTrue([[event.data allKeys] containsObject: @"carrot"]);
    XCTAssertTrue([event.key isEqualToString: @"aKey"]);    
}

-(void)testAllEventsJsonData {
    LDEventModel *event1 = [[LDEventModel alloc] init];
    LDEventModel *event2 = [[LDEventModel alloc] init];
    
    event1.key = @"foo";
    event2.key = @"fi";
    
    LDClient *client = [LDClient sharedInstance];
    LDUserModel *theUser = client.user;
    
    [self.dataManagerMock createCustomEvent:@"foo" withCustomValuesDictionary:nil];
    [self.dataManagerMock createCustomEvent:@"fi" withCustomValuesDictionary:nil];
    
    NSData *eventData = [self.dataManagerMock allEventsJsonData];
    
    NSArray *eventsArray = [NSJSONSerialization JSONObjectWithData:eventData                                                        options:kNilOptions error:nil];

    NSArray *allValues = [eventsArray bk_map:^id(NSDictionary *eventDict) {
        return [eventDict allValues];
    }];
    
    allValues = [allValues flatten];
    
    XCTAssertTrue([allValues containsObject: @"foo"]);
    XCTAssertTrue([allValues containsObject: @"fi"]);
    
    NSDictionary *userDict = (NSDictionary *)eventsArray.firstObject[@"user"];
    NSString *eventUserKey = [userDict objectForKey:@"email"];

    XCTAssertTrue([eventUserKey isEqualToString: theUser.email]);    
}


-(void)testFindOrCreateUser {
    NSString *userKey = @"thisisgus";
    LDUserModel *aUser = [[LDUserModel alloc] init];
    aUser.key = userKey;
    aUser.email = @"gus@anemail.com";
    aUser.updatedAt = [NSDate date];
    aUser.config = user.config;
        
    XCTAssertNotNil(aUser);
    
    LDUserModel *foundAgainUser = [[LDDataManager sharedManager] findUserWithkey: userKey];
    
    XCTAssertNotNil(foundAgainUser);
    XCTAssertEqual(aUser.email, foundAgainUser.email);
}

-(void) testPurgeUsers {
    NSDate *now = [NSDate date];
    
    for(int index = 0; index < kUserCacheSize + 3; index++) {
        LDUserModel *aUser = [[LDUserModel alloc] init];
        aUser.key = [NSString stringWithFormat: @"gus%d", index];
        aUser.email = @"gus@anemail.com";
        
        NSTimeInterval secondsInXHours = index * 60 * 60;
        NSDate *dateInXHours = [now dateByAddingTimeInterval:secondsInXHours];
        aUser.updatedAt = dateInXHours;
    
        NSError *error;
    }
    
    NSString *userKey = @"gus0";

    // TODO add test for removing users
}

-(void)testCreateEventAfterCapacityReached{
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    builder = [builder withCapacity: 2];
    builder = [builder withApiKey: @"AnApiKey"];
    LDConfig *config = [builder build];
    
    OCMStub([clientMock ldConfig]).andReturn(config);
    
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [self.dataManagerMock createFeatureEvent: @"anotherKet" keyValue: YES defaultKeyValue: NO];
    
    
    // TODO ADD TEST FOR checking if events are not created after capacity reached
}

@end

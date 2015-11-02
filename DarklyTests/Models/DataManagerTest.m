//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import <BlocksKit/BlocksKit.h>
#import "Config.h"
#import <Blockskit/BlocksKit.h>
#import "FeatureFlag.h"
#import "DataManager.h"
#import "User.h"
#import "Config.h"
#import "Event.h"
#import "LDClient.h"
#import <OCMock.h>
#import "NSArray+UnitTests.h"
#import "UserEntity.h"

@interface DataManagerTest : DarklyXCTestCase
@property (nonatomic) id clientMock;
@property (nonnull) User *user;

@end

@implementation DataManagerTest
@synthesize clientMock;
@synthesize user;

- (void)setUp {
    [super setUp];
    user = [[User alloc] init];
    user.firstName = @"Bob";
    user.lastName = @"Giffy";
    user.email = @"bob@gmail.com";
    user.updatedAt = [NSDate date];
    
    
    LDClient *client = [LDClient sharedInstance];
    clientMock = OCMPartialMock(client);
    OCMStub([clientMock user]).andReturn(user);
    
    Config *config = [[Config alloc] init];
    config.featuresJsonDictionary = [NSDictionary dictionaryWithObjects:@[@{@"value": @YES}, @{@"value": @NO}]
                                                                forKeys: @[@"ipaduser", @"iosuser"]];
    user.config = config;
    
    NSError *error = nil;
    [MTLManagedObjectAdapter managedObjectFromModel:user
                               insertingIntoContext:[self.dataManagerMock managedObjectContext]
                                              error: &error];
    
    [self.dataManagerMock saveContext];
}

- (void)tearDown {
    [clientMock stopMocking];
    [super tearDown];
}

- (void)testisFlagOnForKey {
    LDClient *client = [LDClient sharedInstance];
    User * theUser = client.user;
    
    BOOL ipaduserFlag = [theUser isFlagOn: @"ipaduser"];
    BOOL iosuserFlag = [theUser isFlagOn: @"iosuser"];
    
    XCTAssertFalse(iosuserFlag);
    XCTAssertTrue(ipaduserFlag);
    
    NSLog(@"Stop");
}

-(void)testCreateFeatureEvent {
    [[DataManager sharedManager] createFeatureEvent:@"afeaturekey" keyValue:NO defaultKeyValue:NO];
    
    Event *lastEvent = [self lastCreatedEvent];
    
    XCTAssertEqualObjects(lastEvent.key, @"afeaturekey");
}

-(Event *)lastCreatedEvent {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"EventEntity"
                                   inManagedObjectContext: [self.dataManagerMock managedObjectContext]]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"key = 'afeaturekey'"];
    request.predicate = predicate;
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSManagedObject *eventMo = [[[self.dataManagerMock managedObjectContext] executeFetchRequest:request                                                                          error:&error] objectAtIndex:0];
    
    return [MTLManagedObjectAdapter modelOfClass:[Event class]
                               fromManagedObject: eventMo
                                           error: &error];
    
    
}

-(void)testAllEvents {
    Event *event1 = [[Event alloc] init];
    Event *event2 = [[Event alloc] init];
    
    event1.key = @"foo";
    event2.key = @"fi";
    
    [self.dataManagerMock createCustomEvent:@"foo" withCustomValuesDictionary:nil];
    [self.dataManagerMock createCustomEvent:@"fi" withCustomValuesDictionary:nil];
    
    [self.dataManagerMock saveContext];
    
    NSArray *eventArray = [self.dataManagerMock allEvents];
    NSArray *eventKeys = [eventArray bk_map:^id(Event *event) {
        return event.key;
    }];
    XCTAssertTrue([eventKeys containsObject:event1.key]);
    XCTAssertTrue([eventKeys containsObject:event2.key]);
}

-(void)testCreateCustomEvent {
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    
    [self.dataManagerMock saveContext];
    
    Event *event = [self.dataManagerMock allEvents].firstObject;

    XCTAssertTrue([[event.data allKeys] containsObject: @"carrot"]);
    XCTAssertTrue([event.key isEqualToString: @"aKey"]);    
}

-(void)testAllEventsJsonData {
    Event *event1 = [[Event alloc] init];
    Event *event2 = [[Event alloc] init];
    
    event1.key = @"foo";
    event2.key = @"fi";
    
    LDClient *client = [LDClient sharedInstance];
    User *theUser = client.user;
    
    [self.dataManagerMock createCustomEvent:@"foo" withCustomValuesDictionary:nil];
    [self.dataManagerMock createCustomEvent:@"fi" withCustomValuesDictionary:nil];
    
    [self.dataManagerMock saveContext];
    
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
    User *aUser = [[User alloc] init];
    aUser.key = userKey;
    aUser.email = @"gus@anemail.com";
    aUser.updatedAt = [NSDate date];
    aUser.config = user.config;
        
    [MTLManagedObjectAdapter managedObjectFromModel:aUser 
                               insertingIntoContext: [[DataManager sharedManager]
                                                      managedObjectContext] error: nil];
    [[DataManager sharedManager] saveContext];
    
    XCTAssertNotNil(aUser);
    
    User *foundAgainUser = [[DataManager sharedManager] findUserWithkey: userKey];
    
    XCTAssertNotNil(foundAgainUser);
    XCTAssertEqual(aUser.email, foundAgainUser.email);
}

-(void) testPurgeUsers {
    NSDate *now = [NSDate date];
    
    for(int index = 0; index < 10; index++) {
        User *aUser = [[User alloc] init];
        aUser.key = [NSString stringWithFormat: @"gus%d", index];
        aUser.email = @"gus@anemail.com";
        
        NSTimeInterval secondsInXHours = index * 60 * 60;
        NSDate *dateInXHours = [now dateByAddingTimeInterval:secondsInXHours];
        aUser.updatedAt = dateInXHours;
    
        NSError *error;
        [MTLManagedObjectAdapter managedObjectFromModel:aUser
                                   insertingIntoContext: [[DataManager sharedManager]
                                                          managedObjectContext] error: &error];
        
        NSLog(@"PRINT BREAK");
    }
    UserEntity *userEntity = [[DataManager sharedManager] findUserEntityWithkey: @"gus1"];

    XCTAssertNotNil(userEntity);
    [[DataManager sharedManager] purgeOldUsers];
    
    userEntity = [[DataManager sharedManager] findUserEntityWithkey: @"gus1"];
    XCTAssertNil(userEntity);
}
@end

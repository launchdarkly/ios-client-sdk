//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDFlagConfigModel.h"
#import "LDDataManager.h"
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
#import "NSArray+UnitTests.h"
#import "LDDataManager+Testable.h"
#import "LDFlagConfigTracker.h"
#import "LDFlagConfigTracker+Testable.h"
#import "LDConfig.h"

NSString * const kMobileKeyMock = @"LDDataManagerTest.mobileKeyMock";

@interface LDDataManagerTest : DarklyXCTestCase
@property (nonatomic, strong) id clientMock;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) LDConfig *config;

@end

@implementation LDDataManagerTest
@synthesize clientMock;
@synthesize user;

- (void)setUp {
    [super setUp];
    self.config = [[LDConfig alloc] initWithMobileKey:kMobileKeyMock];
    self.user = [LDUserModel stubWithKey:nil];

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

-(void)testCreateFlagEvaluationEvents {
    id trackerMock = OCMClassMock([LDFlagConfigTracker class]);
    self.user = [LDUserModel stubWithKey:nil usingTracker:trackerMock];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            [[LDDataManager sharedManager] flushEventsDictionary];

            XCTestExpectation *eventsExpectation = [self expectationWithDescription:@"LDDataManagerTest.testCreateFlagEvaluationEvents.allEvents"];
            [[trackerMock expect] logRequestForFlagKey:flagKey flagConfigValue:flagConfigValue defaultValue:defaultFlagValue];

            [[LDDataManager sharedManager] createFlagEvaluationEventsWithFlagKey:flagKey
                                                                 flagConfigValue:flagConfigValue
                                                                defaultFlagValue:defaultFlagValue
                                                                            user:self.user
                                                                          config:self.config];

            [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
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

-(void)testCreateSummaryEvent_noCounters {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"stubMobileKey"];
    LDFlagConfigTracker *trackerStub = [LDFlagConfigTracker tracker];
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];

    [[LDDataManager sharedManager] createSummaryEventWithTracker:trackerStub config:config];

    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqual(eventDictionaries.count, 0);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

-(void)testAllEventsDictionaryArray {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:@"stubMobileKey"];
    LDEventModel *featureEvent = [LDEventModel stubEventWithKind:kEventModelKindFeature user:self.user config:config];
    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:featureEvent.key
                                                 flagConfigValue:featureEvent.flagConfigValue
                                                defaultFlagValue:featureEvent.defaultValue
                                                            user:self.user
                                                          config:config];
    LDEventModel *customEvent = [LDEventModel stubEventWithKind:kEventModelKindCustom user:self.user config:config];
    [[LDDataManager sharedManager] createCustomEventWithKey:customEvent.key customData:customEvent.data user:self.user config:config];
    LDEventModel *identifyEvent = [LDEventModel stubEventWithKind:kEventModelKindIdentify user:self.user config:config];
    [[LDDataManager sharedManager] createIdentifyEventWithUser:self.user config:config];
    LDFlagConfigTracker *trackerStub = [LDFlagConfigTracker stubTracker];
    LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:trackerStub];
    [[LDDataManager sharedManager] createSummaryEventWithTracker:trackerStub config:config];
    LDEventModel *debugEvent = [LDEventModel stubEventWithKind:kEventModelKindDebug user:self.user config:config];
    [[LDDataManager sharedManager] createDebugEventWithFlagKey:debugEvent.key flagConfigValue:debugEvent.flagConfigValue defaultFlagValue:debugEvent.defaultValue user:self.user config:config];
    NSArray<LDEventModel*> *eventStubs = @[featureEvent, customEvent, identifyEvent, summaryEvent, debugEvent];

    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    
    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
        for (LDEventModel *event in eventStubs) {
            NSPredicate *matchingEventPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
                if (![evaluatedObject isKindOfClass:[NSDictionary class]]) { return NO; }
                NSDictionary *evaluatedEventDictionary = evaluatedObject;
                return [evaluatedEventDictionary[kEventModelKeyKind] isEqualToString:event.kind];
            }];
            NSDictionary *matchingEventDictionary = [[eventDictionaries filteredArrayUsingPredicate:matchingEventPredicate] firstObject];

            XCTAssertNotNil(matchingEventDictionary);
            if (!matchingEventDictionary) {
                NSLog(@"Did not find matching event dictionary for event: %@", event.kind);
                continue;
            }
            XCTAssertTrue([event hasPropertiesMatchingDictionary:matchingEventDictionary]);
        }
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:1];
}

-(void)testFindOrCreateUser {
    NSString *userKey = @"thisisgus";
    LDUserModel *aUser = [[LDUserModel alloc] init];
    aUser.key = userKey;
    aUser.email = @"gus@anemail.com";
    aUser.updatedAt = [NSDate date];
    aUser.flagConfig = user.flagConfig;
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
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion"
                                                                                     flagKey:kLDFlagKeyIsABool
                                                                        eventTrackingContext:[LDEventTrackingContext stub]];
    [manager createFeatureEventWithFlagKey: @"anotherKey" flagConfigValue:flagConfigValue defaultFlagValue:@(NO) user:self.user config:config];
    
    [manager allEventDictionaries:^(NSArray *array) {
        XCTAssertEqual([array count],2);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:10];
}

@end

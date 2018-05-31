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
#import "LDDataManager+Testable.h"
#import "LDFlagConfigTracker.h"
#import "LDFlagConfigTracker+Testable.h"
#import "LDConfig.h"
#import "NSDate+Testable.h"
#import "NSArray+Testable.h"
#import "NSNumber+LaunchDarkly.h"

NSString * const kMobileKeyMock = @"LDDataManagerTest.mobileKeyMock";

@interface LDDataManagerTest : DarklyXCTestCase
@property (nonatomic, strong) id clientMock;
@property (nonatomic, strong) id eventModelMock;
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

    self.clientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([self.clientMock sharedInstance])).andReturn(clientMock);
    OCMStub([self.clientMock ldUser]).andReturn(user);
    OCMStub([self.clientMock ldConfig]).andReturn(self.config);
}

- (void)tearDown {
    [self.clientMock stopMocking];
    self.clientMock = nil;
    [self.eventModelMock stopMocking];
    self.eventModelMock = nil;
    [[LDDataManager sharedManager] flushEventsDictionary];
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
    [LDDataManager sharedManager].lastEventResponseDate = lastResponse;
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

-(void)testCreateFlagEvaluationEvents {
    id trackerMock = OCMClassMock([LDFlagConfigTracker class]);
    self.user = [LDUserModel stubWithKey:nil usingTracker:trackerMock eventTrackingContext:nil];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            [[LDDataManager sharedManager] flushEventsDictionary];

            XCTestExpectation *eventsExpectation = [self expectationWithDescription:@"LDDataManagerTest.testCreateFlagEvaluationEvents.allEvents"];
            [[trackerMock expect] logRequestForFlagKey:flagKey reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultValue:defaultFlagValue];

            [[LDDataManager sharedManager] createFlagEvaluationEventsWithFlagKey:flagKey
                                                               reportedFlagValue:flagConfigValue.value
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
    LDFlagConfigTracker *trackerStub = [LDFlagConfigTracker tracker];
    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];

    [[LDDataManager sharedManager] createSummaryEventWithTracker:trackerStub config:self.config];

    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
        XCTAssertEqual(eventDictionaries.count, 0);
        [expectation fulfill];
    }];
    [self waitForExpectations:@[expectation] timeout:1];
}

-(void)testCreateFeatureEvent_trackEvents_YES {
    LDFlagConfigValue *flagConfigValue = [self setupCreateFeatureEventTestWithTrackEvents:YES];
    [[self.eventModelMock expect] featureEventWithFlagKey:kFlagKeyIsABawler
                                        reportedFlagValue:flagConfigValue.value
                                          flagConfigValue:flagConfigValue
                                         defaultFlagValue:@(NO)
                                                     user:self.user
                                               inlineUser:NO];

    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:kFlagKeyIsABawler
                                               reportedFlagValue:flagConfigValue.value
                                                 flagConfigValue:flagConfigValue
                                                defaultFlagValue:@(NO)
                                                            user:self.user
                                                          config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateFeatureEvent_trackEvents_NO {
    LDFlagConfigValue *flagConfigValue = [self setupCreateFeatureEventTestWithTrackEvents:NO];
    [[self.eventModelMock reject] featureEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any] inlineUser:[OCMArg any]];

    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:kFlagKeyIsABawler
                                               reportedFlagValue:flagConfigValue.value
                                                 flagConfigValue:flagConfigValue
                                                defaultFlagValue:@(NO)
                                                            user:self.user
                                                          config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateFeatureEvent_eventTrackingContext_nil {
    LDFlagConfigValue *flagConfigValue = [self setupCreateFeatureEventTestWithTrackEvents:YES includeTrackingContext:NO];
    [[self.eventModelMock reject] featureEventWithFlagKey:[OCMArg any]
                                        reportedFlagValue:[OCMArg any]
                                          flagConfigValue:[OCMArg any]
                                         defaultFlagValue:[OCMArg any]
                                                     user:[OCMArg any]
                                               inlineUser:[OCMArg any]];

    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:kFlagKeyIsABawler
                                               reportedFlagValue:flagConfigValue.value
                                                 flagConfigValue:flagConfigValue
                                                defaultFlagValue:@(NO)
                                                            user:self.user
                                                          config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_lastEventResponseDate_systemDate_debugEventsUntilDate_createEvent {
    //lastEventResponseDate < systemDate < debugEventsUntilDate         create event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [[self.eventModelMock expect] debugEventWithFlagKey:kFlagKeyIsABawler reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultFlagValue:@(NO) user:self.user];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_systemDate_lastEventResponseDate_debugEventsUntilDate_createEvent {
    //systemDate < lastEventResponseDate < debugEventsUntilDate         create event        //system time not right, set too far in the past, but lastEventResponse hasn't reached debug
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    [[self.eventModelMock expect] debugEventWithFlagKey:kFlagKeyIsABawler reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultFlagValue:@(NO) user:self.user];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_lastEventResponseDate_debugEventsUntilDate_systemDate_dontCreateEvent {
    //lastEventResponseDate < debugEventsUntilDate < systemDate         no event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:[NSDate date]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_debugEventsUntilDate_lastEventResponseDate_systemDate_dontCreateEvent {
    //debugEventsUntilDate < lastEventResponseDate < systemDate         no event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:-2.0]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_debugEventsUntilDate_systemDate_lastEventResponseDate_dontCreateEvent {
    //debugEventsUntilDate < systemDate < lastEventResponseDate         no event
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:1.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:-1.0]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_systemDate_debugEventsUntilDate_lastEventResponseDate_dontCreateEvent {
    //systemDate < debugEventsUntilDate < lastEventResponseDate         no event            //system time not right, set too far in the past, lastEventResponse past debug
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:2.0] debugUntil:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_missingDebugEventsUntilDate_dontCreateEvent {
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:nil];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testCreateDebugEvent_missingEventTrackingContext_dontCreateEvent {
    LDFlagConfigValue *flagConfigValue = [self setupCreateDebugEventTestWithLastEventResponseDate:[NSDate dateWithTimeIntervalSinceNow:-1.0] debugUntil:nil includeTrackingContext:NO];
    [[self.eventModelMock reject] debugEventWithFlagKey:[OCMArg any] reportedFlagValue:[OCMArg any] flagConfigValue:[OCMArg any] defaultFlagValue:[OCMArg any] user:[OCMArg any]];

    [[LDDataManager sharedManager] createDebugEventWithFlagKey:kFlagKeyIsABawler
                                             reportedFlagValue:flagConfigValue.value
                                               flagConfigValue:flagConfigValue
                                              defaultFlagValue:@(NO)
                                                          user:self.user
                                                        config:self.config];

    [self.eventModelMock verify];
}

-(void)testAllEventsDictionaryArray {
    LDEventModel *featureEvent = [LDEventModel stubEventWithKind:kEventModelKindFeature user:self.user config:self.config];
    [[LDDataManager sharedManager] createFeatureEventWithFlagKey:featureEvent.key
                                               reportedFlagValue:featureEvent.reportedValue
                                                 flagConfigValue:featureEvent.flagConfigValue
                                                defaultFlagValue:featureEvent.defaultValue
                                                            user:self.user
                                                          config:self.config];
    LDEventModel *customEvent = [LDEventModel stubEventWithKind:kEventModelKindCustom user:self.user config:self.config];
    [[LDDataManager sharedManager] createCustomEventWithKey:customEvent.key customData:customEvent.data user:self.user config:self.config];
    LDEventModel *identifyEvent = [LDEventModel stubEventWithKind:kEventModelKindIdentify user:self.user config:self.config];
    [[LDDataManager sharedManager] createIdentifyEventWithUser:self.user config:self.config];
    LDFlagConfigTracker *trackerStub = [LDFlagConfigTracker stubTracker];
    LDEventModel *summaryEvent = [LDEventModel summaryEventWithTracker:trackerStub];
    [[LDDataManager sharedManager] createSummaryEventWithTracker:trackerStub config:self.config];
    LDEventModel *debugEvent = [LDEventModel stubEventWithKind:kEventModelKindDebug user:self.user config:self.config];
    [[LDDataManager sharedManager] createDebugEventWithFlagKey:debugEvent.key
                                             reportedFlagValue:debugEvent.reportedValue
                                               flagConfigValue:debugEvent.flagConfigValue
                                              defaultFlagValue:debugEvent.defaultValue
                                                          user:self.user
                                                        config:self.config];
    NSArray<LDEventModel*> *eventStubs = @[featureEvent, customEvent, identifyEvent, summaryEvent, debugEvent];

    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];
    
    [[LDDataManager sharedManager] allEventDictionaries:^(NSArray *eventDictionaries) {
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
    self.config.capacity = @(2);

    XCTestExpectation *expectation = [self expectationWithDescription:@"All events dictionary expectation"];

    LDDataManager *manager = [LDDataManager sharedManager];
    [manager.eventsArray removeAllObjects];
    
    [manager createCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user config:self.config];
    [manager createCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user config:self.config];
    [manager createCustomEventWithKey:@"aKey" customData: @{@"carrot": @"cake"} user:self.user config:self.config];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true"
                                                                                     flagKey:kLDFlagKeyIsABool
                                                                        eventTrackingContext:[LDEventTrackingContext stub]];
    [manager createFeatureEventWithFlagKey: @"anotherKey"
                         reportedFlagValue:flagConfigValue.value
                           flagConfigValue:flagConfigValue
                          defaultFlagValue:@(NO)
                                      user:self.user
                                    config:self.config];

    [manager allEventDictionaries:^(NSArray *array) {
        XCTAssertEqual([array count],2);
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:1.0];
}

@end

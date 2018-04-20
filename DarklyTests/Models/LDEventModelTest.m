//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDEventModel.h"
#import "LDEventModel+Testable.h"
#import "LDUserModel.h"
#import "LDUserModel+Equatable.h"
#import "LDUserModel+Stub.h"
#import "NSDate+ReferencedDate.h"
#import "LDFlagConfigTracker+Testable.h"
#import "NSInteger+Testable.h"

extern NSString * const kEventModelKeyUser;
extern NSString * const kEventModelKeyUserKey;
extern NSString * const kEventModelKeyInlineUser;

extern NSString * const kUserAttributeConfig;

extern NSString * const kEventModelKindFeature;
extern NSString * const kEventModelKindCustom;
extern NSString * const kEventModelKindIdentify;

extern const NSTimeInterval kLDFlagConfigTrackerTrackingInterval;

NSString * const testMobileKey = @"EventModelTest.testMobileKey";

@interface LDEventModelTest : XCTestCase
@property LDUserModel *user;
@end

@implementation LDEventModelTest
- (void)setUp {
    [super setUp];
    self.user = [[LDUserModel alloc] init];
    self.user.key = [[NSUUID UUID] UUIDString];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFeatureEventWithKey {
    NSArray *boolValues = @[@NO, @YES];
    for (NSNumber *value in boolValues) {
        BOOL boolValue = [value boolValue];
        NSInteger referenceMillis = [[NSDate date] millisSince1970];
        LDEventModel *event = [LDEventModel featureEventWithFlagKey:@"red" flagValue:value defaultFlagValue:value userValue:self.user inlineUser:boolValue];

        XCTAssertEqualObjects(event.key, @"red");
        XCTAssertEqualObjects(event.kind, kEventModelKindFeature);
        XCTAssertEqualObjects(event.value, value);
        XCTAssertEqualObjects(event.defaultValue, value);
        XCTAssertTrue([event.user isEqual:self.user ignoringAttributes:@[]]);
        XCTAssertEqual(event.inlineUser, boolValue);
        XCTAssertTrue(event.creationDate >= referenceMillis);
    }
}

- (void)testCustomEvent {
    NSDictionary *dictionary = @{@"red": @"is not blue"};
    NSArray *boolValues = @[@NO, @YES];
    for (NSNumber *value in boolValues) {
        BOOL boolValue = [value boolValue];
        NSInteger referenceMillis = [[NSDate date] millisSince1970];
        LDEventModel *event = [LDEventModel customEventWithKey:@"red" customData:dictionary userValue:self.user inlineUser:boolValue];

        XCTAssertEqualObjects(event.key, @"red");
        XCTAssertEqualObjects(event.kind, kEventModelKindCustom);
        XCTAssertEqualObjects(event.data, dictionary);
        XCTAssertTrue([event.user isEqual:self.user ignoringAttributes:@[]]);
        XCTAssertEqual(event.inlineUser, boolValue);
        XCTAssertTrue(event.creationDate >= referenceMillis);
    }
}

- (void)testIdentifyEvent {
    NSInteger referenceMillis = [[NSDate date] millisSince1970];
    LDEventModel *event = [LDEventModel identifyEventWithUser:self.user];

    XCTAssertEqualObjects(event.kind, kEventModelKindIdentify);
    XCTAssertTrue([event.user isEqual:self.user ignoringAttributes:@[]]);
    XCTAssertEqual(event.inlineUser, YES);
    XCTAssertTrue(event.creationDate >= referenceMillis);
}

-(void)testSummaryEvent {
    NSDate *creationDate = [NSDate date];
    LDFlagConfigTracker *trackerStub = [LDFlagConfigTracker stubTracker];
    LDEventModel *event = [LDEventModel summaryEventWithTracker:trackerStub];

    XCTAssertNotNil(event);
    NSInteger startDateMillis = [[creationDate dateByAddingTimeInterval:kLDFlagConfigTrackerTrackingInterval] millisSince1970];
    XCTAssertTrue(Approximately(event.startDateMillis, startDateMillis, 10));
    XCTAssertTrue(Approximately(event.endDateMillis, [creationDate millisSince1970], 10));
    XCTAssertTrue([trackerStub hasPropertiesMatchingDictionary:event.flagRequestSummary]);
}

-(void)testEncodeAndDecodeEvent {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.inlineUserInEvents = YES;
    for (NSString *eventKind in [LDEventModel allEventKinds]) {
        LDEventModel *originalEvent = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];

        NSData *encodedEventData = [NSKeyedArchiver archivedDataWithRootObject:originalEvent];
        XCTAssertNotNil(encodedEventData);

        LDEventModel *decodedEvent = [NSKeyedUnarchiver unarchiveObjectWithData:encodedEventData];
        XCTAssertTrue([originalEvent isEqual:decodedEvent]);
    }
}

-(void)testDictionaryValueAndInitWithDictionary {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.inlineUserInEvents = YES;
    for (NSString *eventKind in [LDEventModel allEventKinds]) {
        LDEventModel *originalEvent = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];
        NSDictionary *eventDictionary = [originalEvent dictionaryValueUsingConfig:config];

        LDEventModel *restoredEvent = [[LDEventModel alloc] initWithDictionary:eventDictionary];
        XCTAssertTrue([originalEvent isEqual:restoredEvent]);
    }
}

-(void)testDictionaryValue_inlineUser_YES {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.inlineUserInEvents = YES;
    for (NSString *eventKind in [LDEventModel eventKindsWithCommonFields]) {
        LDEventModel *originalEvent = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];
        NSDictionary *eventDictionary = [originalEvent dictionaryValueUsingConfig:config];

        XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
        XCTAssertNil(eventDictionary[kEventModelKeyUserKey]);
        LDUserModel *restoredUser = [[LDUserModel alloc] initWithDictionary:eventDictionary[kEventModelKeyUser]];
        XCTAssertTrue([originalEvent.user isEqual:restoredUser ignoringAttributes:@[kUserAttributeConfig]]);
        XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
    }
}

-(void)testDictionaryValue_inlineUser_NO {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.inlineUserInEvents = NO;
    for (NSString *eventKind in [LDEventModel eventKindsWithCommonFields]) {
        LDEventModel *originalEvent = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];
        NSDictionary *eventDictionary = [originalEvent dictionaryValueUsingConfig:config];

        if (![eventKind isEqualToString:kEventModelKindIdentify]) {
            XCTAssertNil(eventDictionary[kEventModelKeyUser]);
            XCTAssertNotNil(eventDictionary[kEventModelKeyUserKey]);
            XCTAssertTrue([originalEvent.user.key isEqualToString:eventDictionary[kEventModelKeyUserKey]]);
        } else {    //identify events always inline the user
            XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
            XCTAssertNil(eventDictionary[kEventModelKeyUserKey]);
            LDUserModel *restoredUser = [[LDUserModel alloc] initWithDictionary:eventDictionary[kEventModelKeyUser]];
            XCTAssertTrue([originalEvent.user isEqual:restoredUser ignoringAttributes:@[kUserAttributeConfig]]);
        }
        XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
    }
}

-(void)testEventDictionaryOmitsUserFlagConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    LDEventModel *eventStub = [[LDEventModel alloc] initCustomEventWithKey:@"eventStubKey" customData:@{} userValue:self.user inlineUser:YES];
    NSDictionary *subject = [eventStub dictionaryValueUsingConfig:config][kEventModelKeyUser];

    XCTAssertNotNil(subject);
    XCTAssertTrue(subject.allKeys.count > 0);
    XCTAssertFalse([subject.allKeys containsObject:kUserAttributeConfig]);
}

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDEventModel.h"
#import "LDEventModel+Testable.h"
#import "LDUserModel.h"
#import "LDUserModel+Testable.h"
#import "NSDate+ReferencedDate.h"
#import "LDFlagConfigTracker+Testable.h"
#import "NSDate+Testable.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDFlagCounter+Testable.h"
#import "NSArray+Testable.h"
#import "LDFlagValueCounter+Testable.h"
#import "LDEventTrackingContext+Testable.h"
#import "NSArray+Testable.h"
#import "NSNumber+LaunchDarkly.h"

extern NSString * const kEventModelKeyUser;
extern NSString * const kEventModelKeyUserKey;
extern NSString * const kEventModelKeyInlineUser;

extern NSString * const kUserAttributeConfig;

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

- (void)testInitAndFeatureEvent {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            LDMillisecond creationDateMillis = [[NSDate date] millisSince1970];
            LDEventModel *featureEvent = [LDEventModel featureEventWithFlagKey:flagKey
                                                             reportedFlagValue:flagConfigValue.value
                                                               flagConfigValue:flagConfigValue
                                                              defaultFlagValue:defaultFlagValue
                                                                          user:self.user
                                                                    inlineUser:NO];

            XCTAssertTrue([featureEvent hasPropertiesMatchingFlagKey:flagKey
                                                           eventKind:kEventModelKindFeature
                                                     flagConfigValue:flagConfigValue
                                                    defaultFlagValue:defaultFlagValue
                                                                user:self.user
                                                          inlineUser:NO
                                                  creationDateMillis:creationDateMillis]);
        }
    }
}

- (void)testCustomEvent {
    NSDictionary *dictionary = @{@"red": @"is not blue"};
    NSArray *boolValues = @[@NO, @YES];
    for (NSNumber *value in boolValues) {
        BOOL boolValue = [value boolValue];
        LDMillisecond referenceMillis = [[NSDate date] millisSince1970];
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
    LDMillisecond referenceMillis = [[NSDate date] millisSince1970];
    LDEventModel *event = [LDEventModel identifyEventWithUser:self.user];

    XCTAssertEqualObjects(event.kind, kEventModelKindIdentify);
    XCTAssertTrue([event.user isEqual:self.user ignoringAttributes:@[]]);
    XCTAssertEqual(event.inlineUser, YES);
    XCTAssertTrue(event.creationDate >= referenceMillis);
}

- (void)testSummaryEvent {
    NSDate *creationDate = [NSDate date];
    LDFlagConfigTracker *trackerStub = [LDFlagConfigTracker stubTracker];

    LDEventModel *event = [LDEventModel summaryEventWithTracker:trackerStub];

    XCTAssertNotNil(event);
    LDMillisecond startDateMillis = [[creationDate dateByAddingTimeInterval:kLDFlagConfigTrackerTrackingInterval] millisSince1970];
    XCTAssertTrue(Approximately(event.startDateMillis, startDateMillis, 10));
    XCTAssertTrue(Approximately(event.endDateMillis, [creationDate millisSince1970], 10));
    //Verify flagCounter dictionaries match the tracker
    XCTAssertEqual(event.flagRequestSummary.allKeys.count, trackerStub.flagCounters.allKeys.count);
    if (event.flagRequestSummary.allKeys.count != trackerStub.flagCounters.allKeys.count) { return; }
    for (NSString *flagKey in trackerStub.flagCounters.allKeys) {
        LDFlagCounter *flagCounter = trackerStub.flagCounters[flagKey];
        NSDictionary *flagCounterDictionary = event.flagRequestSummary[flagKey];

        XCTAssertEqualObjects(flagCounterDictionary[kLDFlagCounterKeyDefaultValue], flagCounter.defaultValue);
        NSArray<NSDictionary*> *counterDictionaries = flagCounterDictionary[kLDFlagCounterKeyCounters];
        XCTAssertEqual(counterDictionaries.count, flagCounter.flagValueCounters.count);
        if (counterDictionaries.count != flagCounter.flagValueCounters.count) { continue; }
        for (LDFlagValueCounter *flagValueCounter in flagCounter.flagValueCounters) {
            NSDictionary *selectedCounterDictionary = [counterDictionaries dictionaryForFlagValueCounter:flagValueCounter];
            XCTAssertNotNil(selectedCounterDictionary, @"counter dictionary not found for flagValueCounter: %@", [flagValueCounter description]);
            if (!selectedCounterDictionary) { continue; }

            XCTAssertEqualObjects(selectedCounterDictionary[kLDFlagConfigValueKeyValue], flagValueCounter.flagConfigValue.value);
            XCTAssertEqual([selectedCounterDictionary[kLDFlagConfigValueKeyVariation] integerValue], flagValueCounter.flagConfigValue.variation);
            XCTAssertEqualObjects(selectedCounterDictionary[kLDFlagConfigValueKeyVersion], flagValueCounter.flagConfigValue.flagVersion);
            XCTAssertEqual([selectedCounterDictionary[kLDFlagValueCounterKeyCount] integerValue], flagValueCounter.count);
            XCTAssertNil(selectedCounterDictionary[kLDFlagValueCounterKeyUnknown]);
            XCTAssertNil(selectedCounterDictionary[kLDFlagConfigValueKeyFlagVersion]);
            XCTAssertNil(selectedCounterDictionary[kLDEventTrackingContextKeyTrackEvents]);
            XCTAssertNil(selectedCounterDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
        }
    }
}

- (void)testInitAndDebugEvent {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            LDMillisecond creationDateMillis = [[NSDate date] millisSince1970];
            LDEventModel *debugEvent = [LDEventModel debugEventWithFlagKey:flagKey
                                                         reportedFlagValue:flagConfigValue.value
                                                           flagConfigValue:flagConfigValue
                                                          defaultFlagValue:defaultFlagValue
                                                                      user:self.user];

            XCTAssertTrue([debugEvent hasPropertiesMatchingFlagKey:flagKey
                                                           eventKind:kEventModelKindDebug
                                                     flagConfigValue:flagConfigValue
                                                    defaultFlagValue:defaultFlagValue
                                                                user:self.user
                                                          inlineUser:YES
                                                  creationDateMillis:creationDateMillis]);
        }
    }
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

-(void)testDictionaryValue {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [LDEventModel allEventKinds]) {
        LDEventModel *event = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];

        NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

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
        } else {
            XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyValue]);
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
}

-(void)testDictionaryValue_inlineUser_YES {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.inlineUserInEvents = YES;
    for (NSString *eventKind in [LDEventModel eventKindsWithCommonFields]) {
        LDEventModel *event = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];

        NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

        XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
        XCTAssertNil(eventDictionary[kEventModelKeyUserKey]);
        LDUserModel *restoredUser = [[LDUserModel alloc] initWithDictionary:eventDictionary[kEventModelKeyUser]];
        XCTAssertTrue([event.user isEqual:restoredUser ignoringAttributes:@[kUserAttributeConfig]]);
        XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
    }
}

-(void)testDictionaryValue_flagRequestEvents_missingFlagConfigValue {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [LDEventModel eventKindsForFlagRequests]) {
        LDEventModel *event = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];
        event.reportedValue = event.defaultValue;
        event.flagConfigValue = nil;

        NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

        //Checks that differ from testDictionaryValue
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyValue], event.defaultValue);
        XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyVariation]);
        XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyVersion]);

        //Checks that are the same as in testDictionaryValue
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyKind], event.kind);
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyKey], event.key);
        if (event.alwaysInlinesUser) {
            XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
        } else {
            XCTAssertEqualObjects(eventDictionary[kEventModelKeyUserKey], event.user.key);
        }
        XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
        XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyCreationDate] ldMillisecondValue], event.creationDate, 1));
        XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyFlagVersion]);
        XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyTrackEvents]);
        XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyDefault], event.defaultValue);
    }
}

-(void)testDictionaryValue_flagRequestEvents_flagConfigValueHasNullValue {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [LDEventModel eventKindsForFlagRequests]) {
        LDEventModel *event = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];
        event.reportedValue = event.defaultValue;
        event.flagConfigValue.value = [NSNull null];

        NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

        //Checks that differ from testDictionaryValue
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyValue], event.defaultValue);

        //Checks that are the same as in testDictionaryValue
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyKind], event.kind);
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyKey], event.key);
        if (event.alwaysInlinesUser) {
            XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
        } else {
            XCTAssertEqualObjects(eventDictionary[kEventModelKeyUserKey], event.user.key);
        }
        XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
        XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyCreationDate] ldMillisecondValue], event.creationDate, 1));
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyVariation], @(event.flagConfigValue.variation));
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyVersion], event.flagConfigValue.flagVersion);
        XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyFlagVersion]);
        XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyTrackEvents]);
        XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyDefault], event.defaultValue);
    }
}

-(void)testDictionaryValue_summaryEvents_missingFlagConfigValue {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker stubTrackerUseKnownValues:NO];
    LDEventModel *event = [LDEventModel summaryEventWithTracker:tracker];

    NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

    //Checks that differ from testDictionaryValue
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyStartDate], @(event.startDateMillis));
    XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyEndDate] ldMillisecondValue], event.endDateMillis, 10));
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyFeatures], event.flagRequestSummary);

    //Checks that are the same as in testDictionaryValue
    for (NSString *flagKey in tracker.flagCounters.allKeys) {
        LDFlagCounter *flagCounter = tracker.flagCounters[flagKey];
        NSDictionary *flagCounterDictionary = eventDictionary[kEventModelKeyFeatures][flagKey];
        LDFlagValueCounter *flagValueCounter = flagCounter.valueCounters.firstObject;
        XCTAssertEqual(((NSArray*)flagCounterDictionary[kLDFlagCounterKeyCounters]).count, 1);
        NSDictionary *flagConfigValueSummary = [flagCounterDictionary[kLDFlagCounterKeyCounters] firstObject];
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyValue], [LDFlagConfigValue defaultValueForFlagKey:flagKey]);
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagValueCounterKeyUnknown], @(YES));
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagValueCounterKeyCount], @(flagValueCounter.count));
        XCTAssertNil(flagConfigValueSummary[kLDFlagConfigValueKeyVersion]);
        XCTAssertNil(flagConfigValueSummary[kLDFlagConfigValueKeyVariation]);
    }
}

-(void)testDictionaryValue_summaryEvents_flagConfigValueHasNullValue {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker stubTrackerWithNullValuesInFlagConfigValue];
    LDEventModel *event = [LDEventModel summaryEventWithTracker:tracker];

    NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

    XCTAssertEqualObjects(eventDictionary[kEventModelKeyKind], event.kind);
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyStartDate], @(event.startDateMillis));
    XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyEndDate] ldMillisecondValue], event.endDateMillis, 10));
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyFeatures], event.flagRequestSummary);
    for (NSString *flagKey in tracker.flagCounters.allKeys) {
        LDFlagCounter *flagCounter = tracker.flagCounters[flagKey];
        NSDictionary *flagCounterDictionary = eventDictionary[kEventModelKeyFeatures][flagKey];
        LDFlagValueCounter *flagValueCounter = flagCounter.valueCounters.firstObject;
        LDFlagConfigValue *flagConfigValue = flagValueCounter.flagConfigValue;
        NSDictionary *flagConfigValueSummary = [flagCounterDictionary[kLDFlagCounterKeyCounters] firstObject];
        XCTAssertEqual(((NSArray*)flagCounterDictionary[kLDFlagCounterKeyCounters]).count, 1);
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyValue], [LDFlagConfigValue defaultValueForFlagKey:flagKey]);
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyVariation], @(flagConfigValue.variation));
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyVersion], flagConfigValue.flagVersion);
        XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagValueCounterKeyCount], @(flagValueCounter.count));
        XCTAssertNil(flagConfigValueSummary[kLDFlagValueCounterKeyUnknown]);
    }
}

-(void)testDictionaryValue_flagRequestEvents_missingFlagVersion {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [LDEventModel eventKindsForFlagRequests]) {
        LDEventModel *event = [LDEventModel stubEventWithKind:eventKind user:self.user config:config];
        event.flagConfigValue.flagVersion = nil;

        NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

        //Checks that differ from testDictionaryValue
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyVersion], @(event.flagConfigValue.modelVersion));

        //Checks that are the same as in testDictionaryValue
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyKind], event.kind);
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyKey], event.key);
        if (event.alwaysInlinesUser) {
            XCTAssertNotNil(eventDictionary[kEventModelKeyUser]);
        } else {
            XCTAssertEqualObjects(eventDictionary[kEventModelKeyUserKey], event.user.key);
        }
        XCTAssertNil(eventDictionary[kEventModelKeyInlineUser]);
        XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyCreationDate] ldMillisecondValue], event.creationDate, 1));
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyValue], event.flagConfigValue.value);
        XCTAssertEqualObjects(eventDictionary[kLDFlagConfigValueKeyVariation], @(event.flagConfigValue.variation));
        XCTAssertNil(eventDictionary[kLDFlagConfigValueKeyFlagVersion]);
        XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyTrackEvents]);
        XCTAssertNil(eventDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
        XCTAssertEqualObjects(eventDictionary[kEventModelKeyDefault], event.defaultValue);
    }
}

-(void)testDictionaryValue_summaryEvents_missingFlagVersion {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker stubTrackerIncludeFlagVersion:NO];
    LDEventModel *event = [LDEventModel summaryEventWithTracker:tracker];

    NSDictionary *eventDictionary = [event dictionaryValueUsingConfig:config];

    //Checks that differ from testDictionaryValue
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyStartDate], @(event.startDateMillis));
    XCTAssertTrue(Approximately([eventDictionary[kEventModelKeyEndDate] ldMillisecondValue], event.endDateMillis, 10));
    XCTAssertEqualObjects(eventDictionary[kEventModelKeyFeatures], event.flagRequestSummary);

    //Checks that are the same as in testDictionaryValue
    for (NSString *flagKey in tracker.flagCounters.allKeys) {
        LDFlagCounter *flagCounter = tracker.flagCounters[flagKey];
        NSDictionary *flagCounterDictionary = eventDictionary[kEventModelKeyFeatures][flagKey];
        for (LDFlagValueCounter *flagValueCounter in flagCounter.valueCounters) {
            LDFlagConfigValue *flagConfigValue = flagValueCounter.flagConfigValue;
            NSDictionary *flagConfigValueSummary = [flagCounterDictionary[kLDFlagCounterKeyCounters] dictionaryForFlagValueCounter:flagValueCounter];
            XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyVersion], @(flagConfigValue.modelVersion));
            XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyValue], flagConfigValue.value);
            XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagConfigValueKeyVariation], @(flagConfigValue.variation));
            XCTAssertEqualObjects(flagConfigValueSummary[kLDFlagValueCounterKeyCount], @(flagValueCounter.count));
            XCTAssertNil(eventDictionary[kLDFlagValueCounterKeyUnknown]);
        }
    }
}

-(void)testEventDictionaryOmitsUserFlagConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    LDEventModel *eventStub = [[LDEventModel alloc] initCustomEventWithKey:@"eventStubKey" customData:@{} userValue:self.user inlineUser:YES];
    
    NSDictionary *eventDictionary = [eventStub dictionaryValueUsingConfig:config][kEventModelKeyUser];

    XCTAssertNotNil(eventDictionary);
    XCTAssertTrue(eventDictionary.allKeys.count > 0);
    XCTAssertFalse([eventDictionary.allKeys containsObject:kUserAttributeConfig]);
}

@end

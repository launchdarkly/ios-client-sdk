//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDEventModel.h"
#import "LDEventModel+Equatable.h"
#import "LDUserModel.h"
#import "LDUserModel+Equatable.h"
#import "LDUserModel+Stub.h"
#import "NSDate+ReferencedDate.h"

extern NSString * const kKeyUser;
extern NSString * const kKeyUserKey;
extern NSString * const kUserAttributeConfig;

extern NSString * const kEventNameFeature;
extern NSString * const kEventNameCustom;
extern NSString * const kEventNameIdentify;

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
        LDEventModel *event = [LDEventModel featureEventWithKey:@"red" keyValue:value defaultKeyValue:value userValue:self.user inlineUser:boolValue];

        XCTAssertEqualObjects(event.key, @"red");
        XCTAssertEqualObjects(event.kind, kEventNameFeature);
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
        LDEventModel *event = [LDEventModel customEventWithKey:@"red" andDataDictionary:dictionary userValue:self.user inlineUser:boolValue];

        XCTAssertEqualObjects(event.key, @"red");
        XCTAssertEqualObjects(event.kind, kEventNameCustom);
        XCTAssertEqualObjects(event.data, dictionary);
        XCTAssertTrue([event.user isEqual:self.user ignoringAttributes:@[]]);
        XCTAssertEqual(event.inlineUser, boolValue);
        XCTAssertTrue(event.creationDate >= referenceMillis);
    }
}

- (void)testIdentifyEvent {
    NSInteger referenceMillis = [[NSDate date] millisSince1970];
    LDEventModel *event = [LDEventModel identifyEventWithUser:self.user];

    XCTAssertEqualObjects(event.kind, kEventNameIdentify);
    XCTAssertTrue([event.user isEqual:self.user ignoringAttributes:@[]]);
    XCTAssertEqual(event.inlineUser, YES);
    XCTAssertTrue(event.creationDate >= referenceMillis);
}

-(void)testEncodeAndDecodeEvent {
    for (NSString *eventKind in [self eventKinds]) {
        LDEventModel *originalEvent = [self eventForKind:eventKind inlineUser:YES];

        NSData *encodedEventData = [NSKeyedArchiver archivedDataWithRootObject:originalEvent];
        XCTAssertNotNil(encodedEventData);

        LDEventModel *decodedEvent = [NSKeyedUnarchiver unarchiveObjectWithData:encodedEventData];
        XCTAssertTrue([originalEvent isEqual:decodedEvent]);
    }
}

-(void)testDictionaryValueAndInitWithDictionary {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [self eventKinds]) {
        LDEventModel *originalEvent = [self eventForKind:eventKind inlineUser:YES];
        NSDictionary *eventDictionary = [originalEvent dictionaryValueUsingConfig:config];

        LDEventModel *restoredEvent = [[LDEventModel alloc] initWithDictionary:eventDictionary];
        XCTAssertTrue([originalEvent isEqual:restoredEvent]);
    }
}

-(void)testDictionaryValue_inlineUser_YES {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [self eventKinds]) {
        LDEventModel *originalEvent = [self eventForKind:eventKind inlineUser:YES];
        NSDictionary *eventDictionary = [originalEvent dictionaryValueUsingConfig:config];

        XCTAssertNotNil(eventDictionary[kKeyUser]);
        XCTAssertNil(eventDictionary[kKeyUserKey]);
        LDUserModel *restoredUser = [[LDUserModel alloc] initWithDictionary:eventDictionary[kKeyUser]];
        XCTAssertTrue([originalEvent.user isEqual:restoredUser ignoringAttributes:@[kUserAttributeConfig]]);
    }
}

-(void)testDictionaryValue_inlineUser_NO {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    for (NSString *eventKind in [self eventKinds]) {
        LDEventModel *originalEvent = [self eventForKind:eventKind inlineUser:NO];
        NSDictionary *eventDictionary = [originalEvent dictionaryValueUsingConfig:config];

        if (![eventKind isEqualToString:kEventNameIdentify]) {
            XCTAssertNil(eventDictionary[kKeyUser]);
            XCTAssertNotNil(eventDictionary[kKeyUserKey]);
            XCTAssertTrue([originalEvent.user.key isEqualToString:eventDictionary[kKeyUserKey]]);
        } else {    //identify events always inline the user
            XCTAssertNotNil(eventDictionary[kKeyUser]);
            XCTAssertNil(eventDictionary[kKeyUserKey]);
            LDUserModel *restoredUser = [[LDUserModel alloc] initWithDictionary:eventDictionary[kKeyUser]];
            XCTAssertTrue([originalEvent.user isEqual:restoredUser ignoringAttributes:@[kUserAttributeConfig]]);
        }
    }
}

-(void)testEventDictionaryOmitsUserFlagConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    LDEventModel *eventStub = [[LDEventModel alloc] initCustomEventWithKey:@"eventStubKey" andDataDictionary:@{} userValue:self.user inlineUser:YES];
    NSDictionary *subject = [eventStub dictionaryValueUsingConfig:config][kKeyUser];

    XCTAssertNotNil(subject);
    XCTAssertTrue(subject.allKeys.count > 0);
    XCTAssertFalse([subject.allKeys containsObject:kUserAttributeConfig]);
}

#pragma mark Helpers
-(LDEventModel*)eventForKind:(NSString*)kind inlineUser:(BOOL)inlineUser {
    if ([kind isEqualToString:kEventNameFeature]) {
        return [LDEventModel featureEventWithKey:[[NSUUID UUID] UUIDString] keyValue:@7 defaultKeyValue:@3 userValue:self.user inlineUser:inlineUser];
    }
    if ([kind isEqualToString:kEventNameCustom]) {
        return [LDEventModel customEventWithKey:[[NSUUID UUID] UUIDString] andDataDictionary:@{@"red": @"is not blue"} userValue:self.user inlineUser:inlineUser];
    }
    if ([kind isEqualToString:kEventNameIdentify]) {
        return [LDEventModel identifyEventWithUser:self.user];
    }

    return nil;
}

-(NSArray<NSString*>*)eventKinds {
    return @[kEventNameFeature, kEventNameCustom, kEventNameIdentify];
}

@end

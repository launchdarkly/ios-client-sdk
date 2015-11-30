//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDEvent.h"

@interface EventTest : XCTestCase

@end

@implementation EventTest
- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFeatureEventWithKeyCreatesEventWithDefaults {
    LDEvent *event = [[LDEvent alloc] featureEventWithKey:@"red" keyValue:NO defaultKeyValue:NO];
    
    XCTAssertEqual(event.key, @"red");
    XCTAssertEqual(event.kind, @"feature");
    XCTAssertFalse(event.featureKeyValue);
    XCTAssertFalse(event.isDefault);
}

- (void)testCustomEventWithKeyCreatesEventWithDefaults {
    NSDictionary *dictionary = @{@"red": @"is not blue"};
    LDEvent *event = [[LDEvent alloc] customEventWithKey:@"red"
                                   andDataDictionary: dictionary];
    
    XCTAssertEqual(event.key, @"red");
    XCTAssertEqual(event.kind, @"custom");
    XCTAssertEqual([event.data allValues].firstObject,
                   [dictionary allValues].firstObject);
}

@end

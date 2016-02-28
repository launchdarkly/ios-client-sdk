//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDEventModel.h"
#import "LDUserModel.h"

@interface LDEventModelTest : XCTestCase
@property LDUserModel *user;
@end

@implementation LDEventModelTest
- (void)setUp {
    [super setUp];
    self.user = [[LDUserModel alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFeatureEventWithKeyCreatesEventWithDefaults {
    LDEventModel *event = [[LDEventModel alloc] initFeatureEventWithKey:@"red" keyValue:NO defaultKeyValue:NO userValue:self.user ];
    
    XCTAssertEqual(event.key, @"red");
    XCTAssertEqual(event.kind, @"feature");
    XCTAssertFalse(event.featureKeyValue);
    XCTAssertFalse(event.isDefault);
}

- (void)testCustomEventWithKeyCreatesEventWithDefaults {
    NSDictionary *dictionary = @{@"red": @"is not blue"};
    
    LDEventModel *event = [[LDEventModel alloc] initCustomEventWithKey:@"red" andDataDictionary:dictionary userValue:self.user];
                 
    XCTAssertEqual(event.key, @"red");
    XCTAssertEqual(event.kind, @"custom");
    XCTAssertEqual([event.data allValues].firstObject,
                   [dictionary allValues].firstObject);
}

@end

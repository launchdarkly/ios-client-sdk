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
    LDEventModel *event = [[LDEventModel alloc] initFeatureEventWithKey:@"red" keyValue:[NSNumber numberWithBool:NO] defaultKeyValue:[NSNumber numberWithBool:NO] userValue:self.user];
    
    XCTAssertEqualObjects(event.key, @"red");
    XCTAssertEqualObjects(event.kind, @"feature");
    XCTAssertFalse([(NSNumber *)event.value boolValue]);
    XCTAssertFalse([(NSNumber *)event.isDefault boolValue]);
}

- (void)testCustomEventWithKeyCreatesEventWithDefaults {
    NSDictionary *dictionary = @{@"red": @"is not blue"};
    
    LDEventModel *event = [[LDEventModel alloc] initCustomEventWithKey:@"red" andDataDictionary:dictionary userValue:self.user];
                 
    XCTAssertEqualObjects(event.key, @"red");
    XCTAssertEqualObjects(event.kind, @"custom");
    XCTAssertEqual([event.data allValues].firstObject,
                   [dictionary allValues].firstObject);
}

@end

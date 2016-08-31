//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigModel.h"


@interface LDFlagConfigModelTest : XCTestCase
@property (strong, nonatomic) NSString *filepath;
@property (strong, nonatomic) NSDictionary *json;

@end

@implementation LDFlagConfigModelTest

- (void)setUp {
    [super setUp];
    self.filepath = [[NSBundle bundleForClass:[LDFlagConfigModelTest class]] pathForResource:@"feature_flags"
                                                                           ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.filepath];
    self.json = [NSJSONSerialization JSONObjectWithData:data
                                                options:kNilOptions
                                                  error:&error];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testIsFlagOnForKey {
    LDFlagConfigModel *config = [[LDFlagConfigModel alloc] initWithDictionary: self.json];
    
    XCTAssertTrue([config configFlagValue: @"isABawler"]);
    XCTAssertFalse([config configFlagValue: @"isConnected"]);
    XCTAssertFalse([(NSNumber *)[config configFlagValue: @"devices.hasipad"] boolValue]);
}

- (void)testDoesFlagExist {
    LDFlagConfigModel *config = [[LDFlagConfigModel alloc] initWithDictionary: self.json];

    XCTAssertTrue([config doesConfigFlagExist: @"isABawler"]);
    XCTAssertTrue([config doesConfigFlagExist: @"isConnected"]);
    XCTAssertTrue([config doesConfigFlagExist: @"devices.hasipad"]);
    XCTAssertFalse([config doesConfigFlagExist: @"caramel"]);
}

@end

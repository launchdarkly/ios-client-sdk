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
    
    XCTAssertTrue([config isFlagOn: @"isABawler"]);
    XCTAssertFalse([config isFlagOn: @"isConnected"]);
    XCTAssertFalse([config isFlagOn: @"devices.hasipad"]);
}

- (void)testDoesFlagExist {
    LDFlagConfigModel *config = [[LDFlagConfigModel alloc] initWithDictionary: self.json];

    XCTAssertTrue([config doesFlagExist: @"isABawler"]);
    XCTAssertTrue([config doesFlagExist: @"isConnected"]);
    XCTAssertTrue([config doesFlagExist: @"devices.hasipad"]);
    XCTAssertFalse([config doesFlagExist: @"caramel"]);
}

@end

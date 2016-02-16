//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigModel.h"
#import "LDFeatureFlagModel.h"


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

- (void)testConfigObjectCreatedFromJson {
    // TODO Rewrite test
//    NSError *error = nil;
//
//    LDFlagConfigModel *config = [MTLJSONAdapter modelOfClass:[LDFlagConfig class]
//                               fromJSONDictionary:self.json
//                                            error: &error];
//    NSLog(@"Any objects?");
//    
//    NSDictionary *featuresJsonDictionary = config.featuresJsonDictionary;
//    
//    XCTAssertNotNil(config);
//    XCTAssertEqual([[featuresJsonDictionary allKeys] count], 7);
}

- (void)testFeatureFlagObjectsFromJson {
    // TODO Rewrite test
//    NSError *error = nil;
//    
//    LDFlagConfig *config = [MTLJSONAdapter modelOfClass:[LDFlagConfig class]
//                               fromJSONDictionary:self.json
//                                            error: &error];
//    NSArray *features = config.features;
//    XCTAssertEqual([features count], 3);
//    
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"key==%@",@"devices.hasipad"];
//    LDFeatureFlag *hasIpadFlag = [features filteredArrayUsingPredicate:predicate].firstObject;
//    XCTAssertFalse(hasIpadFlag.isOn);
//    
//    predicate = [NSPredicate predicateWithFormat:@"key==%@",@"isConnected"];
//    LDFeatureFlag *isConnectedFlag = [features filteredArrayUsingPredicate:predicate].firstObject;
//    XCTAssertFalse(isConnectedFlag.isOn);
//    
//    predicate = [NSPredicate predicateWithFormat:@"key==%@",@"isANumber"];
//    LDFeatureFlag *isANumberFlag = [features filteredArrayUsingPredicate:predicate].firstObject;
//    XCTAssertFalse(isANumberFlag.isOn);
}

- (void)testFeatureReturnDefaultForNullValue {
    // TODO Rewrite test
//    NSError *error = nil;
//    
//    LDFlagConfigModel *config = [MTLJSONAdapter modelOfClass:[LDFlagConfig class]
//                               fromJSONDictionary:self.json
//                                            error: &error];
//    NSArray *features = config.features;
//    XCTAssertEqual([features count], 3);
//    
//    XCTAssertFalse([config.features containsObject: @"isConnected"]);
}


-(void)testIsFlagOnForKey {
    // TODO: Rewrite test for non mantle
//    NSError *error = nil;
//    
//    LDFlagConfig *config = [MTLJSONAdapter modelOfClass:[LDFlagConfig class]
//                               fromJSONDictionary:self.json
//                                            error: &error];
//    
//    XCTAssertTrue([config isFlagOn: @"isABawler"]);
//    XCTAssertFalse([config isFlagOn: @"isConnected"]);
//    XCTAssertFalse([config isFlagOn: @"devices.hasipad"]);
}

- (void)testDoesFlagExist {
    // TODO: Rewrite test for non mantle
//    NSError *error = nil;
//    
//    LDFlagConfig *config = [MTLJSONAdapter modelOfClass:[LDFlagConfig class]
//                               fromJSONDictionary:self.json
//                                            error: &error];
//
//    XCTAssertTrue([config doesFlagExist: @"isABawler"]);
//    XCTAssertFalse([config doesFlagExist: @"isConnected"]);
//    XCTAssertTrue([config doesFlagExist: @"devices.hasipad"]);
//    XCTAssertFalse([config doesFlagExist: @"caramel"]);
}

@end

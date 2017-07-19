//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigModel.h"


@interface LDFlagConfigModelTest : XCTestCase

@end

@implementation LDFlagConfigModelTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testIsFlagOnForKey {
    LDFlagConfigModel *config = [[LDFlagConfigModel alloc] initWithDictionary: [self dictionaryFromJsonFileNamed:@"feature_flags"]];
    
    XCTAssertTrue([config configFlagValue: @"isABawler"]);
    XCTAssertFalse([config configFlagValue: @"isConnected"]);
    XCTAssertFalse([(NSNumber *)[config configFlagValue: @"devices.hasipad"] boolValue]);
}

- (void)testDoesFlagExist {
    LDFlagConfigModel *config = [[LDFlagConfigModel alloc] initWithDictionary: [self dictionaryFromJsonFileNamed:@"feature_flags"]];

    XCTAssertTrue([config doesConfigFlagExist: @"isABawler"]);
    XCTAssertTrue([config doesConfigFlagExist: @"isConnected"]);
    XCTAssertTrue([config doesConfigFlagExist: @"devices.hasipad"]);
    XCTAssertFalse([config doesConfigFlagExist: @"caramel"]);
}

- (void)testIsEqualToConfig {
    //bool value json
    LDFlagConfigModel *boolConfigIsABool_true = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"boolConfigIsABool-true"]];
    LDFlagConfigModel *boolConfigIsABool_trueCopy = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"boolConfigIsABool-true"]];
    LDFlagConfigModel *boolConfigIsABool_false = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"boolConfigIsABool-false"]];
    LDFlagConfigModel *boolConfigIsABool2_true = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"boolConfigIsABool2-true"]];
    
    XCTAssertFalse([boolConfigIsABool_true isEqualToConfig:nil]);
    XCTAssertTrue([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool_true]);
    XCTAssertTrue([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool_trueCopy]);
    XCTAssertNotNil(boolConfigIsABool_false);
    XCTAssertFalse([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool_false]);
    XCTAssertNotNil(boolConfigIsABool2_true);
    XCTAssertFalse([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool2_true]);
    
    //number value json
    LDFlagConfigModel *numberConfigIsANumber_1 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"numberConfigIsANumber-1"]];
    LDFlagConfigModel *numberConfigIsANumber_1Copy = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"numberConfigIsANumber-1"]];
    LDFlagConfigModel *numberConfigIsANumber_2 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"numberConfigIsANumber-2"]];
    LDFlagConfigModel *numberConfigIsANumber2_1 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"numberConfigIsANumber2-1"]];

    XCTAssertFalse([numberConfigIsANumber_1 isEqualToConfig:nil]);
    XCTAssertTrue([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber_1]);
    XCTAssertTrue([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber_1Copy]);
    XCTAssertNotNil(numberConfigIsANumber_2);
    XCTAssertFalse([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber_2]);
    XCTAssertNotNil(numberConfigIsANumber2_1);
    XCTAssertFalse([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber2_1]);
    
    //string value json
    LDFlagConfigModel *stringConfigIsAString_someString = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"stringConfigIsAString-someString"]];
    LDFlagConfigModel *stringConfigIsAString_someStringCopy = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"stringConfigIsAString-someString"]];
    LDFlagConfigModel *stringConfigIsAString_someStringA = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"stringConfigIsAString-someStringA"]];
    LDFlagConfigModel *stringConfigIsAStringA_someString = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"stringConfigIsAStringA-someString"]];

    XCTAssertFalse([stringConfigIsAString_someString isEqualToConfig:nil]);
    XCTAssertTrue([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAString_someString]);
    XCTAssertTrue([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAString_someStringCopy]);
    XCTAssertNotNil(stringConfigIsAString_someStringA);
    XCTAssertFalse([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAString_someStringA]);
    XCTAssertNotNil(stringConfigIsAStringA_someString);
    XCTAssertFalse([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAStringA_someString]);
    
    //array value json
    LDFlagConfigModel *arrayConfigIsAnArray_123 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"arrayConfigIsAnArray-123"]];
    LDFlagConfigModel *arrayConfigIsAnArray_123Copy = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"arrayConfigIsAnArray-123"]];
    LDFlagConfigModel *arrayConfigIsAnArray_Empty = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"arrayConfigIsAnArray-Empty"]];
    LDFlagConfigModel *arrayConfigIsAnArray_1 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"arrayConfigIsAnArray-1"]];
    LDFlagConfigModel *arrayConfigIsAnArrayA_123 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"arrayConfigIsAnArrayA-123"]];

    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:nil]);
    XCTAssertTrue([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_123]);
    XCTAssertTrue([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_123Copy]);
    XCTAssertNotNil(arrayConfigIsAnArray_Empty);
    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_Empty]);
    XCTAssertNotNil(arrayConfigIsAnArray_1);
    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_1]);
    XCTAssertNotNil(arrayConfigIsAnArrayA_123);
    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArrayA_123]);
    
    //dictionary value json
    LDFlagConfigModel *dictionaryConfigIsADictionary_3Key = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_3KeyCopy = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_Empty = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-Empty"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyA = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyA"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyB = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyB"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyB_124 = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyB-124"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyC = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyC"]];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyC_keyDValueDiffers = [[LDFlagConfigModel alloc] initWithDictionary:[self dictionaryFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyC-keyDValueDiffers"]];

    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:nil]);
    XCTAssertTrue([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_3Key]);
    XCTAssertTrue([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_3KeyCopy]);
    XCTAssertNotNil(dictionaryConfigIsADictionary_Empty);
    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_Empty]);
    XCTAssertNotNil(dictionaryConfigIsADictionary_KeyA);
    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_KeyA]);
    XCTAssertNotNil(dictionaryConfigIsADictionary_KeyB);
    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_KeyB]);
    XCTAssertNotNil(dictionaryConfigIsADictionary_KeyB_124);
    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_KeyB_124]);
    XCTAssertNotNil(dictionaryConfigIsADictionary_KeyC);
    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_KeyC]);
    XCTAssertNotNil(dictionaryConfigIsADictionary_KeyC_keyDValueDiffers);
    XCTAssertFalse([dictionaryConfigIsADictionary_3Key isEqualToConfig:dictionaryConfigIsADictionary_KeyC_keyDValueDiffers]);
}

- (NSDictionary*)dictionaryFromJsonFileNamed:(NSString *)fileName {
    NSString *filepath = [[NSBundle bundleForClass:[LDFlagConfigModelTest class]] pathForResource:fileName
                                                                                           ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    return [NSJSONSerialization JSONObjectWithData:data
                                           options:kNilOptions
                                             error:&error];
}

@end

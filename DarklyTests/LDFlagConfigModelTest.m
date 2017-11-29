//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"


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
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"feature_flags"];
    
    XCTAssertTrue([config configFlagValue: @"isABawler"]);
    XCTAssertFalse([config configFlagValue: @"isConnected"]);
    XCTAssertFalse([(NSNumber *)[config configFlagValue: @"devices.hasipad"] boolValue]);
}

- (void)testDoesFlagExist {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"feature_flags"];

    XCTAssertTrue([config doesConfigFlagExist: @"isABawler"]);
    XCTAssertTrue([config doesConfigFlagExist: @"isConnected"]);
    XCTAssertTrue([config doesConfigFlagExist: @"devices.hasipad"]);
    XCTAssertFalse([config doesConfigFlagExist: @"caramel"]);
}

- (void)testIsEqualToConfigBoolValues {
    LDFlagConfigModel *boolConfigIsABool_true = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"boolConfigIsABool-true"];
    LDFlagConfigModel *boolConfigIsABool_trueCopy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"boolConfigIsABool-true"];
    LDFlagConfigModel *boolConfigIsABool_false = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"boolConfigIsABool-false"];
    LDFlagConfigModel *boolConfigIsABool2_true = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"boolConfigIsABool2-true"];
    
    XCTAssertFalse([boolConfigIsABool_true isEqualToConfig:nil]);
    XCTAssertTrue([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool_true]);
    XCTAssertTrue([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool_trueCopy]);
    XCTAssertNotNil(boolConfigIsABool_false);
    XCTAssertFalse([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool_false]);
    XCTAssertNotNil(boolConfigIsABool2_true);
    XCTAssertFalse([boolConfigIsABool_true isEqualToConfig:boolConfigIsABool2_true]);
    
}

- (void)testIsEqualToConfigNumberValues {
    LDFlagConfigModel *numberConfigIsANumber_1 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"numberConfigIsANumber-1"];
    LDFlagConfigModel *numberConfigIsANumber_1Copy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"numberConfigIsANumber-1"];
    LDFlagConfigModel *numberConfigIsANumber_2 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"numberConfigIsANumber-2"];
    LDFlagConfigModel *numberConfigIsANumber2_1 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"numberConfigIsANumber2-1"];

    XCTAssertFalse([numberConfigIsANumber_1 isEqualToConfig:nil]);
    XCTAssertTrue([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber_1]);
    XCTAssertTrue([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber_1Copy]);
    XCTAssertNotNil(numberConfigIsANumber_2);
    XCTAssertFalse([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber_2]);
    XCTAssertNotNil(numberConfigIsANumber2_1);
    XCTAssertFalse([numberConfigIsANumber_1 isEqualToConfig:numberConfigIsANumber2_1]);
}

- (void)testIsEqualToConfigStringValues {
    LDFlagConfigModel *stringConfigIsAString_someString = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAString-someString"];
    LDFlagConfigModel *stringConfigIsAString_someStringCopy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAString-someString"];
    LDFlagConfigModel *stringConfigIsAString_someStringA = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAString-someStringA"];
    LDFlagConfigModel *stringConfigIsAStringA_someString = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAStringA-someString"];

    XCTAssertFalse([stringConfigIsAString_someString isEqualToConfig:nil]);
    XCTAssertTrue([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAString_someString]);
    XCTAssertTrue([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAString_someStringCopy]);
    XCTAssertNotNil(stringConfigIsAString_someStringA);
    XCTAssertFalse([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAString_someStringA]);
    XCTAssertNotNil(stringConfigIsAStringA_someString);
    XCTAssertFalse([stringConfigIsAString_someString isEqualToConfig:stringConfigIsAStringA_someString]);
}

- (void)testIsEqualToConfigArrayValues {
    LDFlagConfigModel *arrayConfigIsAnArray_123 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArray-123"];
    LDFlagConfigModel *arrayConfigIsAnArray_123Copy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArray-123"];
    LDFlagConfigModel *arrayConfigIsAnArray_Empty = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArray-Empty"];
    LDFlagConfigModel *arrayConfigIsAnArray_1 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArray-1"];
    LDFlagConfigModel *arrayConfigIsAnArrayA_123 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArrayA-123"];

    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:nil]);
    XCTAssertTrue([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_123]);
    XCTAssertTrue([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_123Copy]);
    XCTAssertNotNil(arrayConfigIsAnArray_Empty);
    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_Empty]);
    XCTAssertNotNil(arrayConfigIsAnArray_1);
    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArray_1]);
    XCTAssertNotNil(arrayConfigIsAnArrayA_123);
    XCTAssertFalse([arrayConfigIsAnArray_123 isEqualToConfig:arrayConfigIsAnArrayA_123]);
}

- (void)testIsEqualToConfigDictionaryValues {
    LDFlagConfigModel *dictionaryConfigIsADictionary_3Key = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_3KeyCopy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_Empty = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-Empty"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyA = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyA"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyB = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyB"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyB_124 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyB-124"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyC = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyC"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_KeyC_keyDValueDiffers = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-KeyC-keyDValueDiffers"];

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
@end

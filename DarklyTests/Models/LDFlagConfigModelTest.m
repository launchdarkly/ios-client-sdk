//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "NSJSONSerialization+Testable.h"
#import "NSDictionary+Testable.h"

extern NSString *const kLDFlagConfigJsonDictionaryKeyKey;
extern NSString *const kLDFlagConfigJsonDictionaryKeyValue;
extern NSString *const kLDFlagConfigJsonDictionaryKeyVersion;
extern const NSInteger kLDFlagConfigVersionDoesNotExist;

@interface LDFlagConfigModelTest : XCTestCase

@end

@implementation LDFlagConfigModelTest

-(void)testEncodeAndDecode {
    LDFlagConfigModel *originalConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:originalConfig];
    LDFlagConfigModel *restoredConfig = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([restoredConfig isEqualToConfig:originalConfig]);
}

-(void)testInitWithDictionary_withVersions {
    NSDictionary *flagConfigDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"];
    LDFlagConfigModel *subject = [[LDFlagConfigModel alloc] initWithDictionary:flagConfigDictionary];

    for (NSString *key in [flagConfigDictionary.allKeys copy]) {
        LDFlagConfigValue *flagConfigValueFromDictionary = [[LDFlagConfigValue alloc] initWithObject:flagConfigDictionary[key]];

        XCTAssertTrue([subject.featuresJsonDictionary[key] isEqual:flagConfigValueFromDictionary]);
    }
}

-(void)testInitWithDictionary_withoutVersions {
    NSDictionary *flagConfigDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withoutVersions"];
    LDFlagConfigModel *subject = [[LDFlagConfigModel alloc] initWithDictionary:flagConfigDictionary];

    for (NSString *key in [flagConfigDictionary.allKeys copy]) {
        LDFlagConfigValue *flagConfigValueFromDictionary = [[LDFlagConfigValue alloc] initWithObject:flagConfigDictionary[key]];

        XCTAssertTrue([subject.featuresJsonDictionary[key] isEqual:flagConfigValueFromDictionary]);
    }
}

-(void)testDictionaryValue_includeNullValues_withVersions {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];

    NSDictionary *flagConfigDictionary = [subject dictionaryValueIncludeNulls:YES];
    XCTAssertTrue([subject hasFeaturesEqualToDictionary:flagConfigDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-excludeNulls-withVersions"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testDictionaryValue_excludeNullValues_withVersions {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls-withVersions"];

    NSDictionary *flagConfigDictionary = [subject dictionaryValueIncludeNulls:NO];
    XCTAssertTrue([subject hasFeaturesEqualToDictionary:flagConfigDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testDictionaryValue_includeNullValues_withoutVersions {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withoutVersions"];

    NSDictionary *flagConfigDictionary = [subject dictionaryValueIncludeNulls:YES];
    XCTAssertTrue([subject hasFeaturesEqualToDictionary:flagConfigDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-excludeNulls-withoutVersions"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testDictionaryValue_excludeNullValues_withoutVersions {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls-withoutVersions"];

    NSDictionary *flagConfigDictionary = [subject dictionaryValueIncludeNulls:NO];
    XCTAssertTrue([subject hasFeaturesEqualToDictionary:flagConfigDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withoutVersions"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testFlagConfigValue_withVersions {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"];

    for (NSString *key in [flagValues.allKeys copy]) {
        id targetValue = flagValues[key][kLDFlagConfigJsonDictionaryKeyValue];
        if ([targetValue isKindOfClass:[NSNull class]]) {
            XCTAssertNil([config configFlagValue:key]);
            continue;
        }
        XCTAssertTrue([[config configFlagValue:key] isEqual:targetValue]);
    }

    XCTAssertNil([config configFlagValue:@"someMissingKey"]);
}

-(void)testFlagConfigValue_withoutVersions {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withoutVersions"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withoutVersions"];

    for (NSString *key in [flagValues.allKeys copy]) {
        id targetValue = flagValues[key];
        if ([targetValue isKindOfClass:[NSNull class]]) {
            XCTAssertNil([config configFlagValue:key]);
            continue;
        }
        XCTAssertTrue([[config configFlagValue:key] isEqual:targetValue]);
    }

    XCTAssertNil([config configFlagValue:@"someMissingKey"]);
}

-(void)testFlagConfigVersion_withVersions {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"];

    for (NSString *key in [flagValues.allKeys copy]) {
        NSInteger targetVersion = [(NSNumber*)(flagValues[key])[kLDFlagConfigJsonDictionaryKeyVersion] integerValue];
        XCTAssertTrue([config configFlagVersion:key] == targetVersion);
    }

    XCTAssertTrue([config configFlagVersion:@"someMissingKey"] == kLDFlagConfigVersionDoesNotExist);
}

-(void)testFlagConfigVersion_withoutVersions {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withoutVersions"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withoutVersions"];

    for (NSString *key in [flagValues.allKeys copy]) {
        XCTAssertTrue([config configFlagVersion:key] == kLDFlagConfigVersionDoesNotExist);
    }

    XCTAssertTrue([config configFlagVersion:@"someMissingKey"] == kLDFlagConfigVersionDoesNotExist);
}

- (void)testDoesFlagExist {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"];

    for (NSString *key in [flagValues.allKeys copy]) {
        XCTAssertTrue([config doesConfigFlagExist:key]);
    }

    XCTAssertFalse([config doesConfigFlagExist:@"someMissingKey"]);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyDoesntExist {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelPatchNewFlag"];
    NSString *patchedFlagKey = patch[kLDFlagConfigJsonDictionaryKeyKey];
    BOOL patchedFlagValue = [patch boolValueForKey:kLDFlagConfigJsonDictionaryKeyValue];
    NSInteger patchedFlagVersion = [patch integerValueForKey:kLDFlagConfigJsonDictionaryKeyVersion];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config doesConfigFlagExist:patchedFlagKey]);
    XCTAssertEqual([[config configFlagValue:patchedFlagKey] boolValue], patchedFlagValue);
    XCTAssertEqual([config configFlagVersion:patchedFlagKey], patchedFlagVersion);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyExistsWithPreviousVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelPatchVersion1Flag"];
    NSString *patchedFlagKey = patch[kLDFlagConfigJsonDictionaryKeyKey];
    BOOL patchedFlagValue = [patch boolValueForKey:kLDFlagConfigJsonDictionaryKeyValue];
    NSInteger patchedFlagVersion = [patch integerValueForKey:kLDFlagConfigJsonDictionaryKeyVersion];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config doesConfigFlagExist:patchedFlagKey]);
    XCTAssertEqual([[config configFlagValue:patchedFlagKey] boolValue], patchedFlagValue);
    XCTAssertEqual([config configFlagVersion:patchedFlagKey], patchedFlagVersion);
}

- (void)testAddOrReplaceFromDictionaryWhenPatchValueIsNull {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelPatchVersion2FlagWithNull"];
    NSString *patchedFlagKey = patch[kLDFlagConfigJsonDictionaryKeyKey];
    NSInteger patchedFlagVersion = [patch integerValueForKey:kLDFlagConfigJsonDictionaryKeyVersion];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config doesConfigFlagExist:patchedFlagKey]);
    XCTAssertNil([config configFlagValue:patchedFlagKey]);
    XCTAssertEqual([config configFlagVersion:patchedFlagKey], patchedFlagVersion);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyExistsWithSameVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" useVersion:2];
    NSString *patchedFlagKey = patch[kLDFlagConfigJsonDictionaryKeyKey];
    NSString *originalFlagValue = (NSString*)[config configFlagValue:patchedFlagKey];
    NSInteger originalFlagVersion = [config configFlagVersion:patchedFlagKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config doesConfigFlagExist:patchedFlagKey]);
    XCTAssertEqual([config configFlagValue:patchedFlagKey], originalFlagValue);
    XCTAssertEqual([config configFlagVersion:patchedFlagKey], originalFlagVersion);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyExistsWithLaterVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" useVersion:1];
    NSString *patchedFlagKey = patch[kLDFlagConfigJsonDictionaryKeyKey];
    NSString *originalFlagValue = (NSString*)[config configFlagValue:patchedFlagKey];
    NSInteger originalFlagVersion = [config configFlagVersion:patchedFlagKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config doesConfigFlagExist:patchedFlagKey]);
    XCTAssertEqual([config configFlagValue:patchedFlagKey], originalFlagValue);
    XCTAssertEqual([config configFlagVersion:patchedFlagKey], originalFlagVersion);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsNil {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = nil;

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsEmpty {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = @{};

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsMissingValue {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:kLDFlagConfigJsonDictionaryKeyValue];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsMissingVersion {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:kLDFlagConfigJsonDictionaryKeyVersion];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsUnexpectedFormat {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:kLDFlagConfigJsonDictionaryKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenKeyExistsWithPreviousVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelDeleteVersion2Flag"];
    NSString *deletedFlagKey = delete[kLDFlagConfigJsonDictionaryKeyKey];

    [config deleteFromDictionary:delete];

    XCTAssertFalse([config doesConfigFlagExist:deletedFlagKey]);
}

- (void)testDeleteFromDictionaryWhenKeyDoesntExist {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelDeleteNewFlag"];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenKeyExistsWithSameVersion {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [LDFlagConfigModel deleteFromJsonFileNamed:@"ldFlagConfigModelDeleteVersion2Flag" useVersion:2];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenKeyExistsWithLaterVersion {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [LDFlagConfigModel deleteFromJsonFileNamed:@"ldFlagConfigModelDeleteVersion2Flag" useVersion:1];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenDictionaryIsNil {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = nil;

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenDictionaryIsEmpty {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = @{};

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenDictionaryIsMissingVersion {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [LDFlagConfigModel deleteFromJsonFileNamed:@"ldFlagConfigModelDeleteVersion2Flag" omitKey:kLDFlagConfigJsonDictionaryKeyVersion];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenDictionaryIsUnexpectedFormat {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [LDFlagConfigModel deleteFromJsonFileNamed:@"ldFlagConfigModelDeleteVersion2Flag" omitKey:kLDFlagConfigJsonDictionaryKeyKey];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testIsEqualToConfigBoolValues {
    LDFlagConfigModel *boolConfigIsABool_true = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigModel *boolConfigIsABool_trueCopy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"boolConfigIsABool-true-withVersion"];
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
    LDFlagConfigModel *numberConfigIsANumber_2 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"numberConfigIsANumber-2-withVersion"];
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
    LDFlagConfigModel *stringConfigIsAString_someString = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAString-someString-withVersion"];
    LDFlagConfigModel *stringConfigIsAString_someStringCopy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAString-someString-withVersion"];
    LDFlagConfigModel *stringConfigIsAString_someStringA = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"stringConfigIsAString-someString-withVersionA"];
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
    LDFlagConfigModel *arrayConfigIsAnArray_123 = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArray-123-withVersion"];
    LDFlagConfigModel *arrayConfigIsAnArray_123Copy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"arrayConfigIsAnArray-123-withVersion"];
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
    LDFlagConfigModel *dictionaryConfigIsADictionary_3Key = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key-withVersion"];
    LDFlagConfigModel *dictionaryConfigIsADictionary_3KeyCopy = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key-withVersion"];
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

- (void)testHasFeaturesEqualToDictionary_withVersion {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"];
    NSDictionary *sameDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"];

    XCTAssertTrue([subject hasFeaturesEqualToDictionary:sameDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-excludeNulls-withVersions"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

- (void)testHasFeaturesEqualToDictionary_withoutVersion {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withoutVersions"];
    NSMutableDictionary *sameDictionary = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-withVersions"]];
    for (NSString* key in [sameDictionary.allKeys copy]) {
        NSMutableDictionary *flagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:sameDictionary[key]];
        flagConfigValueDictionary[kLDFlagConfigJsonDictionaryKeyVersion] = @(kLDFlagConfigVersionDoesNotExist);
        sameDictionary[key] = flagConfigValueDictionary;
    }

    XCTAssertTrue([subject hasFeaturesEqualToDictionary:sameDictionary]);

    NSMutableDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-excludeNulls-withoutVersions"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

@end

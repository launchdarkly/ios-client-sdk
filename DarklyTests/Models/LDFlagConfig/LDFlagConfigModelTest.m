//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"
#import "NSJSONSerialization+Testable.h"
#import "NSDictionary+Testable.h"
#import "NSDate+ReferencedDate.h"
#import "NSDate+Testable.h"

extern NSString *const kLDFlagConfigModelKeyKey;

@interface LDFlagConfigModelTest : XCTestCase

@end

@implementation LDFlagConfigModelTest

-(void)testEncodeAndDecode {
    LDFlagConfigModel *originalConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:originalConfig];
    LDFlagConfigModel *restoredConfig = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([restoredConfig isEqualToConfig:originalConfig]);
}

-(void)testInit {
    LDFlagConfigModel *subject = [[LDFlagConfigModel alloc] init];

    XCTAssertNotNil(subject.featuresJsonDictionary);
    XCTAssertTrue(subject.featuresJsonDictionary.count == 0);
}

-(void)testInitWithDictionary {
    NSDictionary *flagConfigDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];
    LDFlagConfigModel *subject = [[LDFlagConfigModel alloc] initWithDictionary:flagConfigDictionary];

    for (NSString *key in [flagConfigDictionary.allKeys copy]) {
        LDFlagConfigValue *flagConfigValueFromDictionary = [[LDFlagConfigValue alloc] initWithObject:flagConfigDictionary[key]];

        XCTAssertTrue([subject.featuresJsonDictionary[key] isEqual:flagConfigValueFromDictionary]);
    }
}

-(void)testInitWithDictionary_nonConfigValues {
    LDFlagConfigModel *targetFlagConfigModel = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    LDFlagConfigModel *flagConfigModel = [LDFlagConfigModel flagConfigWithOnlyFlagValuesFromJsonFileNamed:@"featureFlags"];

    LDFlagConfigModel *restoredFlagConfigModel = [[LDFlagConfigModel alloc] initWithDictionary:flagConfigModel.featuresJsonDictionary];

    XCTAssertEqualObjects([NSSet setWithArray:restoredFlagConfigModel.featuresJsonDictionary.allKeys], [NSSet setWithArray:targetFlagConfigModel.featuresJsonDictionary.allKeys]);
    for (NSString *flagKey in targetFlagConfigModel.featuresJsonDictionary.allKeys) {
        LDFlagConfigValue *targetFlagConfigValue = [targetFlagConfigModel flagConfigValueForFlagKey:flagKey];
        LDFlagConfigValue *flagConfigValue = [restoredFlagConfigModel flagConfigValueForFlagKey:flagKey];

        XCTAssertEqualObjects(flagConfigValue.value, targetFlagConfigValue.value);
        XCTAssertEqual(flagConfigValue.variation, kLDFlagConfigValueItemDoesNotExist);
        XCTAssertNil(flagConfigValue.flagVersion);
        XCTAssertEqual(flagConfigValue.modelVersion, kLDFlagConfigValueItemDoesNotExist);
        XCTAssertNil(flagConfigValue.eventTrackingContext);
    }
}

-(void)testDictionaryValue_includeNullValues {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];

    NSDictionary *flagConfigDictionary = [subject dictionaryValueIncludeNulls:YES];
    XCTAssertTrue([subject hasFeaturesEqualToDictionary:flagConfigDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-excludeNulls"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testDictionaryValue_excludeNullValues {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls"];

    NSDictionary *flagConfigDictionary = [subject dictionaryValueIncludeNulls:NO];
    XCTAssertTrue([subject hasFeaturesEqualToDictionary:flagConfigDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testDictionaryValue_nonConfigValues {
    LDFlagConfigModel *flagConfigModel = [LDFlagConfigModel flagConfigWithOnlyFlagValuesFromJsonFileNamed:@"featureFlags"];

    NSDictionary *flagConfigModelDictionary = [flagConfigModel dictionaryValueIncludeNulls:NO];

    XCTAssertNotNil(flagConfigModelDictionary);
    if (flagConfigModelDictionary == nil) {
        return;
    }
    XCTAssertTrue(flagConfigModelDictionary.count == 0);
}

-(void)testAllFlagValues {
    LDFlagConfigModel *flagConfigModel = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];

    NSDictionary<NSString*, id> *allFlags = flagConfigModel.allFlagValues;

    for (NSString *flagKey in flagConfigModel.featuresJsonDictionary) {
        if ([flagKey isEqualToString:@"isConnected"]) {
            XCTAssertNil(allFlags[flagKey]);
        } else {
            XCTAssertEqualObjects(allFlags[flagKey], [flagConfigModel flagValueForFlagKey:flagKey]);
        }
    }
}

-(void)testFlagConfigValueForFlagKey {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];

    for (NSString *key in [flagValues.allKeys copy]) {
        id targetFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagValues[key]];
        XCTAssertEqualObjects([subject flagConfigValueForFlagKey:key], targetFlagConfigValue);
    }

    XCTAssertNil([subject flagValueForFlagKey:@"someMissingKey"]);
}

-(void)testFlagConfigValueForFlagKeyNil {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    XCTAssertNil([subject flagConfigValueForFlagKey:@"someMissingKey"]);
}

-(void)testFlagValueForFlagKey {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];

    for (NSString *key in [flagValues.allKeys copy]) {
        id targetValue = flagValues[key][kLDFlagConfigValueKeyValue];
        if ([targetValue isKindOfClass:[NSNull class]]) {
            XCTAssertNil([config flagValueForFlagKey:key]);
            continue;
        }
        XCTAssertTrue([[config flagValueForFlagKey:key] isEqual:targetValue]);
    }

    XCTAssertNil([config flagValueForFlagKey:@"someMissingKey"]);
}

-(void)testFlagVersionForFlagKey {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];

    for (NSString *key in [flagValues.allKeys copy]) {
        NSInteger targetVersion = [flagValues[key][kLDFlagConfigValueKeyVersion] integerValue];
        XCTAssertTrue([config flagModelVersionForFlagKey:key] == targetVersion);
    }

    XCTAssertTrue([config flagModelVersionForFlagKey:@"someMissingKey"] == kLDFlagConfigValueItemDoesNotExist);
}

- (void)testContainsFlagKey {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    NSDictionary *flagValues = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];

    for (NSString *key in [flagValues.allKeys copy]) {
        XCTAssertTrue([config containsFlagKey:key]);
    }

    XCTAssertFalse([config containsFlagKey:@"someMissingKey"]);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyDoesntExist {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelPatchNewFlag"];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"ldFlagConfigModelPatchNewFlag" flagKey:nil eventTrackingContext:nil];
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config containsFlagKey:patchedFlagKey]);
    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], flagConfigValue);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyExistsWithPreviousVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelPatchVersion1Flag"];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"ldFlagConfigModelPatchVersion1Flag" flagKey:nil eventTrackingContext:nil];
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config containsFlagKey:patchedFlagKey]);
    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], flagConfigValue);
}

- (void)testAddOrReplaceFromDictionaryWhenPatchValueIsNull {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelPatchVersion2FlagWithNull"];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2FlagWithNull" flagKey:nil eventTrackingContext:nil];
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config containsFlagKey:patchedFlagKey]);
    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], flagConfigValue);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyExistsWithSameVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" useVersion:2];
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];
    LDFlagConfigValue *originalFlagConfigValue = [config flagConfigValueForFlagKey:patchedFlagKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config containsFlagKey:patchedFlagKey]);
    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], originalFlagConfigValue);
}

- (void)testAddOrReplaceFromDictionaryWhenKeyExistsWithLaterVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" useVersion:1];
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];
    LDFlagConfigValue *originalFlagConfigValue = [config flagConfigValueForFlagKey:patchedFlagKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config containsFlagKey:patchedFlagKey]);
    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], originalFlagConfigValue);
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
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:kLDFlagConfigValueKeyValue];
    NSString *patchFlagKey = patch[kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    LDFlagConfigValue *flagConfigValue = [config flagConfigValueForFlagKey:patchFlagKey];
    XCTAssertEqualObjects(flagConfigValue.value, [NSNull null]);
    XCTAssertEqual(flagConfigValue.variation, [patch[kLDFlagConfigValueKeyVariation] integerValue]);
    XCTAssertEqual(flagConfigValue.modelVersion, [patch[kLDFlagConfigValueKeyVersion] integerValue]);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsMissingVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:kLDFlagConfigValueKeyVersion];
    LDFlagConfigValue *patchedFlagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" flagKey:nil eventTrackingContext:nil];
    patchedFlagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], patchedFlagConfigValue);
}

- (void)testAddOrReplaceFromDictionaryWhenFlagConfigModelIsMissingVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest" omitKey:kLDFlagConfigValueKeyVersion];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:nil];
    LDFlagConfigValue *patchedFlagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" flagKey:nil eventTrackingContext:nil];
    NSString *patchedFlagKey = patch[kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertEqualObjects([config flagConfigValueForFlagKey:patchedFlagKey], patchedFlagConfigValue);
}

- (void)testAddOrReplaceFromDictionaryWhenDictionaryIsUnexpectedFormat {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *patch = [LDFlagConfigModel patchFromJsonFileNamed:@"ldFlagConfigModelPatchVersion2Flag" omitKey:kLDFlagConfigModelKeyKey];

    [config addOrReplaceFromDictionary:patch];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenKeyExistsWithPreviousVersion {
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [NSJSONSerialization jsonObjectFromFileNamed:@"ldFlagConfigModelDeleteVersion2Flag"];
    NSString *deletedFlagKey = delete[kLDFlagConfigModelKeyKey];

    [config deleteFromDictionary:delete];

    XCTAssertFalse([config containsFlagKey:deletedFlagKey]);
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
    NSDictionary *delete = [LDFlagConfigModel deleteFromJsonFileNamed:@"ldFlagConfigModelDeleteVersion2Flag" omitKey:kLDFlagConfigValueKeyVersion];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
}

- (void)testDeleteFromDictionaryWhenDictionaryIsUnexpectedFormat {
    LDFlagConfigModel *targetConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    LDFlagConfigModel *config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"ldFlagConfigModelTest"];
    NSDictionary *delete = [LDFlagConfigModel deleteFromJsonFileNamed:@"ldFlagConfigModelDeleteVersion2Flag" omitKey:kLDFlagConfigModelKeyKey];

    [config deleteFromDictionary:delete];

    XCTAssertTrue([config isEqualToConfig:targetConfig]);
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

- (void)testHasFeaturesEqualToDictionary {
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    NSDictionary *sameDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags"];

    XCTAssertTrue([subject hasFeaturesEqualToDictionary:sameDictionary]);

    NSDictionary *differentDictionary = [NSJSONSerialization jsonObjectFromFileNamed:@"featureFlags-excludeNulls"];
    XCTAssertFalse([subject hasFeaturesEqualToDictionary:differentDictionary]);
}

-(void)testDifferingFlagKeysFromConfig_matchingConfig {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];
    LDFlagConfigModel *otherConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];

    XCTAssertNil([flagConfig differingFlagKeysFromConfig:otherConfig]);
}

-(void)testDifferingFlagKeysFromConfig_differentValues {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel stub];
    NSMutableArray<NSString*> *flagKeysWithDifferentValues = [NSMutableArray arrayWithCapacity:[LDFlagConfigValue flagKeys].count];
    for (NSString *flagKeyWithDifferentValue in [LDFlagConfigValue flagKeys]) {
        if ([flagKeyWithDifferentValue isEqualToString:kLDFlagKeyIsANull]) { continue; }    //Null has no alternate value
        [flagKeysWithDifferentValues addObject:flagKeyWithDifferentValue];
        LDFlagConfigModel *otherConfig = [LDFlagConfigModel stubWithAlternateValuesForFlagKeys:flagKeysWithDifferentValues];

        XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:flagKeysWithDifferentValues]);
    }

    //repeat varying the selector instead of the parameter
    LDFlagConfigModel *otherConfig = [LDFlagConfigModel stub];
    [flagKeysWithDifferentValues removeAllObjects];
    for (NSString *flagKeyWithDifferentValue in [LDFlagConfigValue flagKeys]) {
        if ([flagKeyWithDifferentValue isEqualToString:kLDFlagKeyIsANull]) { continue; }    //Null has no alternate value
        [flagKeysWithDifferentValues addObject:flagKeyWithDifferentValue];
        LDFlagConfigModel *flagConfig = [LDFlagConfigModel stubWithAlternateValuesForFlagKeys:flagKeysWithDifferentValues];

        XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:flagKeysWithDifferentValues]);
    }
}

-(void)testDifferingFlagKeysFromConfig_omittedValues {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel stub];
    NSMutableArray<NSString*> *omittedFlagKeys = [NSMutableArray arrayWithCapacity:[LDFlagConfigValue flagKeys].count];
    for (NSString *omittedFlagKey in [LDFlagConfigValue flagKeys]) {
        [omittedFlagKeys addObject:omittedFlagKey];
        LDFlagConfigModel *otherConfig = [LDFlagConfigModel stubOmittingFlagKeys:omittedFlagKeys];

        XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:omittedFlagKeys]);
    }

    //repeat varying the selector instead of the parameter
    LDFlagConfigModel *otherConfig = [LDFlagConfigModel stub];
    [omittedFlagKeys removeAllObjects];
    for (NSString *omittedFlagKey in [LDFlagConfigValue flagKeys]) {
        [omittedFlagKeys addObject:omittedFlagKey];
        LDFlagConfigModel *flagConfig = [LDFlagConfigModel stubOmittingFlagKeys:omittedFlagKeys];

        XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:omittedFlagKeys]);
    }
}

-(void)testDifferingFlagKeysFromConfig_addedValue {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel stub];
    LDFlagConfigModel *otherConfig = [LDFlagConfigModel stub];
    LDFlagConfigValue *addedFlagConfigValue = [LDFlagConfigValue stubForFlagKey:kLDFlagKeyIsABool];
    NSString *addedFlagKey = [NSUUID UUID].UUIDString;
    [otherConfig setFlagConfigValue:addedFlagConfigValue forKey:addedFlagKey];

    XCTAssertEqualObjects([flagConfig differingFlagKeysFromConfig:otherConfig], @[addedFlagKey]);

    //repeat adding the flagConfigValue to otherConfig
    flagConfig = [LDFlagConfigModel stub];
    otherConfig = [LDFlagConfigModel stub];
    [flagConfig setFlagConfigValue:addedFlagConfigValue forKey:addedFlagKey];

    XCTAssertEqualObjects([flagConfig differingFlagKeysFromConfig:otherConfig], @[addedFlagKey]);
}

-(void)testDifferingFlagKeysFromConfig_emptyConfig {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel stub];
    LDFlagConfigModel *otherConfig = [[LDFlagConfigModel alloc] init];

    XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:[LDFlagConfigValue flagKeys]]);

    //repeat making flagConfig empty
    flagConfig = [[LDFlagConfigModel alloc] init];
    otherConfig = [LDFlagConfigModel stub];

    XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:[LDFlagConfigValue flagKeys]]);
}

-(void)testDifferingFlagKeysFromConfig_missingConfig {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel stub];
    LDFlagConfigModel *otherConfig = nil;

    XCTAssertEqualObjects([NSSet setWithArray:[flagConfig differingFlagKeysFromConfig:otherConfig]], [NSSet setWithArray:[LDFlagConfigValue flagKeys]]);
}

-(void)testUpdateEventTrackingContextFromConfig {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext contextWithTrackEvents:NO debugEventsUntilDate:nil];
    LDFlagConfigModel *subject = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags" eventTrackingContext:eventTrackingContext omitKey:nil];
    LDEventTrackingContext *updatedEventTrackingContext = [LDEventTrackingContext contextWithTrackEvents:YES debugEventsUntilDate:[NSDate dateWithTimeIntervalSinceNow:30.0]];
    LDFlagConfigModel *updatedConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags" eventTrackingContext:updatedEventTrackingContext omitKey:nil];

    [subject updateEventTrackingContextFromConfig:updatedConfig];

    for (NSString *flagKey in subject.featuresJsonDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = subject.featuresJsonDictionary[flagKey];
        XCTAssertEqualObjects(flagConfigValue.eventTrackingContext, updatedEventTrackingContext);
    }
}

-(void)testCopy {
    LDFlagConfigModel *originalConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags"];

    LDFlagConfigModel *copiedConfig = [originalConfig copy];

    XCTAssertTrue([copiedConfig isEqualToConfig:originalConfig]);
    XCTAssertFalse(copiedConfig == originalConfig);     //copy is not the same object
    for (NSString *flagKey in originalConfig.featuresJsonDictionary) {
        XCTAssertFalse(originalConfig.featuresJsonDictionary[flagKey] == copiedConfig.featuresJsonDictionary[flagKey]);     //flagConfigValue copy is not the same object as the original
    }
}
@end

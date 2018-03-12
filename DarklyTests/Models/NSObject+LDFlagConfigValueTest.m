//
//  NSObject+LDFlagConfigValueTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSObject+LDFlagConfigValue.h"
#import "NSJSONSerialization+Testable.h"

extern NSString * const kLDFlagConfigJsonDictionaryKeyValue;
extern NSString * const kLDFlagConfigJsonDictionaryKeyVersion;

@interface NSObject_LDFlagConfigValueTest : XCTestCase
@end

@implementation NSObject_LDFlagConfigValueTest

-(void)testIsValueAndVersionDictionary_Yes {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    id subject = (NSDictionary*)flagConfigStub[@"isABool"];

    XCTAssertTrue([subject isValueAndVersionDictionary]);
}

-(void)testIsValueAndVersionDictionary_No_MissingValue {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    id subject = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)flagConfigStub[@"isABool"]];
    subject[kLDFlagConfigJsonDictionaryKeyValue] = nil;

    XCTAssertFalse([subject isValueAndVersionDictionary]);
}

-(void)testIsValueAndVersionDictionary_No_MissingVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    id subject = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)flagConfigStub[@"isABool"]];
    subject[kLDFlagConfigJsonDictionaryKeyVersion] = nil;

    XCTAssertFalse([subject isValueAndVersionDictionary]);
}

-(void)testIsValueAndVersionDictionary_No_VersionIsNotANumber {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    id subject = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)flagConfigStub[@"isABool"]];
    subject[kLDFlagConfigJsonDictionaryKeyVersion] = @"not a number";

    XCTAssertFalse([subject isValueAndVersionDictionary]);
}

-(void)testIsValueAndVersionDictionary_No_EmptyDictionary {
    id subject = [NSJSONSerialization jsonObjectFromFileNamed:@"emptyConfig"];

    XCTAssertFalse([subject isValueAndVersionDictionary]);
}

-(void)testIsValueAndVersionDictionary_No_NotADictionary {
    id subject = @"not a dictionary";

    XCTAssertFalse([subject isValueAndVersionDictionary]);
}

@end

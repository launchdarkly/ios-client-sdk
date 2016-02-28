//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDUserModel.h"

@interface LDUserModelTest : XCTestCase
@end

@implementation LDUserModelTest
- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testNewUserSetupProperly {
    LDUserModel *user = [[LDUserModel alloc] init];
    
    XCTAssertNotNil(user.os);
    XCTAssertNotNil(user.device);
    XCTAssertNotNil(user.updatedAt);
}

-(void)testDictionaryValue {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];

    NSDate *updatedAt = [formatter dateFromString: @"2015-01-06T18:48:22.69Z"];
    
    NSString *filepath = [[NSBundle bundleForClass:[LDUserModelTest class]] pathForResource:@"feature_flags"
                                                                           ofType:@"json"];
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    NSDictionary *serverJson = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                  error:&error];
    
    NSDictionary *userDict = @{ @"key": @"aKey",
                                @"ip": @"123.456.789",
                                @"country": @"USA",
                                @"firstName": @"John",
                                @"lastName": @"Doe",
                                @"email": @"jdub@g.com",
                                @"avatar": @"foo",
                                @"updatedAt": updatedAt,
                                @"config": serverJson,
                                @"custom": @{@"foo": @"Foo"},
                                @"anonymous": @1,
                                @"device": @"iPad",
                                @"os": @"IOS 9.2.1"
                                };
    LDUserModel *user = [[LDUserModel alloc] initWithDictionary:userDict];
    
    NSDictionary *userDict2 = [user dictionaryValue];
        
    NSArray *allKeys = [[userDict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSArray *allKeys2 = [[userDict2 allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    XCTAssertTrue([allKeys isEqualToArray:allKeys2]);
    
    for (id userValue in [userDict allValues]) {
        BOOL hasValue = [[userDict2 allValues] containsObject: userValue];
        
        if ([userValue isKindOfClass: [NSString class]])
            XCTAssertTrue(hasValue);
    }
    
    NSDictionary *customValue = [userDict2 objectForKey:@"custom"];
    XCTAssertTrue([[customValue allKeys] containsObject: @"foo"]);
    XCTAssertTrue([[customValue allValues] containsObject: @"Foo"]);
    
    NSDate *updateAtDate = [formatter dateFromString:[userDict2 objectForKey:@"updatedAt"]];
    
    XCTAssertEqual([updateAtDate compare:[userDict objectForKey:@"updatedAt"]], NSOrderedSame);
    
    NSDictionary *config2 = [userDict2 objectForKey: @"config"];
 
    NSArray *originalKeys = [[serverJson objectForKey:@"items"] allKeys];
    NSArray *configKeys = [[config2 objectForKey:@"featuresJsonDictionary"] allKeys];
    
    XCTAssertTrue([originalKeys isEqualToArray:configKeys]);

    NSLog(@"Stop");
}

@end

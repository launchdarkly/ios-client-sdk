//
//  LDUserModel+Stub.m
//  DarklyTests
//
//  Created by Mark Pokorny on 12/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "Darkly/LDUserModel.h"
#import "LDUserModel+Stub.h"
#import "LDUserModel+Equatable.h"
#import "LDFlagConfigModel+Testable.h"

NSString * const userModelStubIp = @"123.456.789.000";
NSString * const userModelStubCountry = @"stubCountry";
NSString * const userModelStubName = @"stubName";
NSString * const userModelStubFirstName = @"stubFirstName";
NSString * const userModelStubLastName = @"stubLastName";
NSString * const userModelStubEmail = @"stub@email.com";
NSString * const userModelStubAvatar = @"stubAvatar";
NSString * const userModelStubDevice = @"iPhone";
NSString * const userModelStubOs = @"IOS 11.2.1";
NSString * const userModelStubCustomKey = @"userModelStubCustomKey";
NSString * const userModelStubCustomValue = @"userModelStubCustomValue";

@implementation LDUserModel (Stub)
+(instancetype)stubWithKey:(NSString*)key {
    LDUserModel *stub = [[LDUserModel alloc] init];
    stub.key = key.length ? key : [[NSUUID UUID] UUIDString];
    stub.ip = userModelStubIp;
    stub.country = userModelStubCountry;
    stub.name = userModelStubName;
    stub.firstName = userModelStubFirstName;
    stub.lastName = userModelStubLastName;
    stub.email = userModelStubEmail;
    stub.avatar = userModelStubAvatar;
    stub.custom = [LDUserModel customStub];
    stub.config = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls-withVersions"];

    return stub;
}

+(NSDictionary*)customStub {
    //If you add new values that are non-string type, you might need to add the type to
    //-[LDUserModel+Equatable matchesDictionary: includeFlags: includePrivateAttributes: privateAttributes:] to handle the new type.
    return @{userModelStubCustomKey: userModelStubCustomValue};
}
@end

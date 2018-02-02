//
//  LDUserModel+Stub.h
//  DarklyTests
//
//  Created by Mark Pokorny on 12/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

extern NSString * const userModelStubIp;
extern NSString * const userModelStubCountry;
extern NSString * const userModelStubName;
extern NSString * const userModelStubFirstName;
extern NSString * const userModelStubLastName;
extern NSString * const userModelStubEmail;
extern NSString * const userModelStubAvatar;
extern NSString * const userModelStubDevice;
extern NSString * const userModelStubOs;
extern NSString * const userModelStubCustomKey;
extern NSString * const userModelStubCustomValue;

@interface LDUserModel (Stub)
+(instancetype)stubWithKey:(NSString*)key;
+(NSDictionary*)customStub;
@end

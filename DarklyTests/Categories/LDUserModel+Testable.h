//
//  LDUserModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 1/9/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
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

@interface LDUserModel (Testable)
+(instancetype)stubWithKey:(NSString*)key;
+(NSDictionary*)customStub;
/**
 -[LDUserModel dictionaryValueWithFlags: includePrivateAttributes: config:] intentionally omits the private attributes LIST from the dictionary when includePrivateAttributes == YES to satisfy an LD server requirement. This method allows control over including that list for testing.
 */
-(NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate config:(LDConfig*)config includePrivateAttributeList:(BOOL)includePrivateList;
@end

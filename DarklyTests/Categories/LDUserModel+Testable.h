//
//  LDUserModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 1/9/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@class LDEventTrackingContext;

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

extern NSString * const kUserAttributeKey;
extern NSString * const kUserAttributeUpdatedAt;
extern NSString * const kUserAttributeConfig;
extern NSString * const kUserAttributeAnonymous;
extern NSString * const kUserAttributePrivateAttributes;
extern NSString * const kUserAttributeDevice;
extern NSString * const kUserAttributeOs;

extern NSString * const kFlagKeyIsABawler;

@interface LDUserModel (Testable)
@property (nonatomic, strong) LDFlagConfigTracker *flagConfigTracker;

+(instancetype)stubWithKey:(NSString*)key;
+(instancetype)stubWithKey:(NSString*)key usingTracker:(LDFlagConfigTracker*)tracker eventTrackingContext:(LDEventTrackingContext*)eventTrackingContext;
+(NSDictionary*)customStub;
+(LDUserModel*)userFrom:(NSString*)jsonUser;
/**
 -[LDUserModel dictionaryValueWithFlags: includePrivateAttributes: config:] intentionally omits the private attributes LIST from the dictionary when includePrivateAttributes == YES to satisfy an LD server requirement. This method allows control over including that list for testing.
 */
-(NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate config:(LDConfig*)config includePrivateAttributeList:(BOOL)includePrivateList;
-(BOOL)isEqual:(id)object ignoringAttributes:(NSArray<NSString*>*)ignoredAttributes;
-(BOOL)matchesDictionary:(NSDictionary *)dictionary includeFlags:(BOOL)includeConfig includePrivateAttributes:(BOOL)includePrivate privateAttributes:(NSArray<NSString*> *)privateAttributes;
@end

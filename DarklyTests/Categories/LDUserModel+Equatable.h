//
//  LDUserModel+Equatable.h
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

extern NSString * const kUserAttributeKey;
extern NSString * const kUserAttributeUpdatedAt;
extern NSString * const kUserAttributeConfig;
extern NSString * const kUserAttributeAnonymous;
extern NSString * const kUserAttributePrivateAttributes;
extern NSString * const kUserAttributeDevice;
extern NSString * const kUserAttributeOs;

@interface LDUserModel (Equatable)
-(BOOL)isEqual:(id)object ignoringAttributes:(NSArray<NSString*>*)ignoredAttributes;
-(BOOL)matchesDictionary:(NSDictionary *)dictionary includeFlags:(BOOL)includeConfig includePrivateAttributes:(BOOL)includePrivate privateAttributes:(NSArray<NSString*> *)privateAttributes;
@end

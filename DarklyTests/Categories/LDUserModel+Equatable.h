//
//  LDUserModel+Equatable.h
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

extern NSString * const kUserPropertyNameKey;
extern NSString * const kUserPropertyNameUpdatedAt;
extern NSString * const kUserPropertyNameConfig;
extern NSString * const kUserPropertyNameAnonymous;
extern NSString * const kUserPropertyNamePrivateAttributes;

@interface LDUserModel (Equatable)
-(BOOL) isEqual:(id)object ignoringProperties:(NSArray<NSString*>*)ignoredProperties;
-(BOOL)matchesDictionary:(NSDictionary *)dictionary includeConfig:(BOOL)includeConfig includePrivateProperties:(BOOL)includePrivate privatePropertyNames:(NSArray<NSString*> *)privateProperties;
@end

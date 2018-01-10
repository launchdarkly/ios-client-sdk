//
//  LDUserModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/9/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDUserModel+Testable.h"
#import "LDUserModel+Equatable.h"

@implementation LDUserModel (Testable)
-(NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate privateAttributesFromConfig:(NSArray<NSString *> *)configPrivateAttributes includePrivateAttributeList:(BOOL)includePrivateList {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[self dictionaryValueWithFlagConfig:includeFlags includePrivateAttributes:includePrivate privateAttributesFromConfig:configPrivateAttributes]];
    dictionary[kUserAttributePrivateAttributes] = includePrivateList ? self.privateAttributes : nil;
    return dictionary;
}
@end

//
//  LDUserModel+Equatable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDUserModel+Equatable.h"
#import "NSDictionary+StringKey_Matchable.h"

@implementation LDUserModel (Equatable)
-(BOOL) isEqual:(id)object ignoringProperties:(NSArray<NSString*>*)ignoredProperties {
    LDUserModel *otherUser = (LDUserModel*)object;
    if (otherUser == nil) {
        return NO;
    }
    NSDictionary *dictionary = [self dictionaryValue];
    NSDictionary *otherDictionary = [otherUser dictionaryValue];
    NSArray *differingKeys = [dictionary keysWithDifferentValuesIn: otherDictionary ignoringKeys: ignoredProperties];
    return (differingKeys == nil || [differingKeys count] == 0);
}
@end

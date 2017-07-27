//
//  NSMutableDictionary+NullRemovable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSMutableDictionary+NullRemovable.h"

@implementation NSMutableDictionary (NullRemovable)
- (NSMutableDictionary *)removeNullValues {
    for (NSString *key in [self allKeys]) {
        id comparisonObject = [self objectForKey:key];
        if ([comparisonObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *comparisonDictionary = [[NSMutableDictionary dictionaryWithDictionary:(NSDictionary*)comparisonObject] removeNullValues];
            self[key] = comparisonDictionary;
        }
        else {
            if (comparisonObject == [NSNull null]) {
                [self removeObjectForKey:key];
            }
        }
    }
    return self;
}
@end

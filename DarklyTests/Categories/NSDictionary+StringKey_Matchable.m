//
//  NSDictionary+NSDictionary_StringKey_Matchable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSDictionary+StringKey_Matchable.h"

@implementation NSDictionary (StringKey_Matchable)
-(NSArray*)keysWithDifferentValuesIn:(id)object {
    if (object == nil) { return [self allKeys]; }
    if (self == object) { return nil; } //Pointers are equal
    if (![object isKindOfClass:[NSDictionary class]]) { return [self allKeys]; }    //Different classes
    
    NSDictionary *otherDictionary = (NSDictionary*)object;
    NSMutableArray *differingKeys = [[NSMutableArray alloc] init];
    for (NSString* key in [self allKeys]) {
        id value = self[key];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *stringValue = (NSString*)value;
            NSString *otherStringValue = (NSString*)otherDictionary[key];
            if ([stringValue isEqualToString:otherStringValue]) { continue; }
            [differingKeys addObject:key];
        }
        else if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *numberValue = (NSNumber*)value;
            NSNumber *otherNumberValue = (NSNumber*)otherDictionary[key];
            if ([numberValue isEqual:otherNumberValue]) { continue; }
            [differingKeys addObject:key];
        }
        else if ([value isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dictionaryValue = (NSDictionary*)value;
            NSDictionary *otherDictionaryValue = (NSDictionary*)otherDictionary[key];
            if ([[[dictionaryValue allKeys] firstObject] isKindOfClass:[NSString class]]) {
                NSArray *differingValueKeys = [dictionaryValue keysWithDifferentValuesIn:otherDictionaryValue]; //Recursion here!!
                if (differingValueKeys == nil || [differingValueKeys count] == 0) { continue; }
                [differingKeys addObject:key];
                for (NSString *differingKey in differingValueKeys) {
                    [differingKeys addObject:[NSString stringWithFormat:@"%@.%@", key, differingKey]];  //Add key.differingKey to the list
                }
            }
            else {
                if ([dictionaryValue isEqualToDictionary:otherDictionary]) { continue; }
                [differingKeys addObject:key];
            }
        }
        else {
            id otherValue = otherDictionary[key];
            if ([value isEqual:otherValue]) { continue; }
            [differingKeys addObject:key];
        }
    }
    
    return differingKeys;
}
@end

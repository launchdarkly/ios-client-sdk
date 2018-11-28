//
//  NSDictionary+NSDictionary_StringKey_Matchable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSDictionary+StringKey_Matchable.h"

@implementation NSDictionary (StringKey_Matchable)
-(NSArray*)keysWithDifferentValuesIn:(id)object ignoringKeys:(NSArray*)ignoreKeys{
    if (object == nil) { return [self allKeys]; }
    if (self == object) { return nil; } //Pointers are equal
    if (![object isKindOfClass:[NSDictionary class]]) { return [self allKeys]; }    //Different classes
    
    NSDictionary *otherDictionary = (NSDictionary*)object;
    NSMutableSet *differingKeys = [[NSMutableSet alloc] init];
    
    NSMutableSet *allKeys = [NSMutableSet setWithArray:[self allKeys]];
    [allKeys addObjectsFromArray:[otherDictionary allKeys]];
    
    //Compare key values
    for (NSString* key in [allKeys copy]) {
        if ([ignoreKeys containsObject:key]) { continue; }
        id value = self[key];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *stringValue = (NSString*)value;
            id otherValue = otherDictionary[key];
            if ([otherValue isKindOfClass:[NSString class]]) {
                NSString *otherStringValue = (NSString*)otherValue;
                if ([stringValue isEqualToString:otherStringValue]) { continue; }
            }
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
                NSArray *differingValueKeys = [dictionaryValue keysWithDifferentValuesIn:otherDictionaryValue ignoringKeys:[self ignoreKeysForKey:key fromKeys:ignoreKeys]]; //Recursion here!!
                if (differingValueKeys == nil || [differingValueKeys count] == 0) { continue; }
                [differingKeys addObject:key];
                for (NSString *differingKey in differingValueKeys) {
                    [differingKeys addObject:[NSString stringWithFormat:@"%@.%@", key, differingKey]];  //Add key.differingKey to the list
                }
            }
            else {
                if (dictionaryValue.count == 0 && otherDictionaryValue.count == 0) { continue; }    //isEqualToDictionary fails for empty dictionaries!!
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
    
    return [differingKeys allObjects];
}

//Unwraps keys with "key.subkey" format and returns an array of subkeys
-(NSArray*)ignoreKeysForKey:(NSString*)key fromKeys:(NSArray*)ignoreKeys {
    if ([key length] == 0 || [ignoreKeys count] == 0) { return nil; }
    NSString *prefix = [NSString stringWithFormat:@"%@.", key];
    NSPredicate *matchingPrefixPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        if (![evaluatedObject isKindOfClass:[NSString class]]) { return NO; }
        NSString *evaluatedKey = (NSString*)evaluatedObject;
        return [evaluatedKey hasPrefix:prefix];
    }];
    NSArray *matchingIgnoreKeys = [ignoreKeys filteredArrayUsingPredicate:matchingPrefixPredicate];
    if ([matchingIgnoreKeys count] == 0) { return matchingIgnoreKeys; }
    NSMutableArray *unwrappedMatchingIgnoreKeys = [NSMutableArray arrayWithCapacity:[matchingIgnoreKeys count]];
    [matchingIgnoreKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *wrappedKey = (NSString*)obj;
        NSString *unwrappedKey = [wrappedKey stringByReplacingOccurrencesOfString:prefix withString:@""];
        [unwrappedMatchingIgnoreKeys addObject:unwrappedKey];
    }];
    return unwrappedMatchingIgnoreKeys;
}
@end

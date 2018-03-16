//
//  NSObject+LDFlagConfigValue.m
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSObject+LDFlagConfigValue.h"

extern NSString * const kLDFlagConfigJsonDictionaryKeyValue;
extern NSString * const kLDFlagConfigJsonDictionaryKeyVersion;

@implementation NSObject(LDFlagConfigValue)

-(BOOL)isValueAndVersionDictionary {
    if (![self isKindOfClass:[NSDictionary class]]) { return NO; }
    NSDictionary *dictionaryObject = (NSDictionary*)self;
    if (![dictionaryObject.allKeys containsObject:kLDFlagConfigJsonDictionaryKeyValue]) { return NO; }
    if (![dictionaryObject.allKeys containsObject:kLDFlagConfigJsonDictionaryKeyVersion]) { return NO; }
    if (![dictionaryObject[kLDFlagConfigJsonDictionaryKeyVersion] isKindOfClass:[NSNumber class]]) { return NO; }

    return YES;
}

@end

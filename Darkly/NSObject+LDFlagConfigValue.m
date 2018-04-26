//
//  NSObject+LDFlagConfigValue.m
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSObject+LDFlagConfigValue.h"

extern NSString * const kLDFlagConfigValueKeyValue;
extern NSString * const kLDFlagConfigValueKeyVersion;

@implementation NSObject(LDFlagConfigValue)

-(BOOL)isValueAndVersionDictionary {
    if (![self isKindOfClass:[NSDictionary class]]) { return NO; }
    NSDictionary *dictionaryObject = (NSDictionary*)self;
    if (![dictionaryObject.allKeys containsObject:kLDFlagConfigValueKeyValue]) { return NO; }
    if (![dictionaryObject.allKeys containsObject:kLDFlagConfigValueKeyVersion]) { return NO; }
    if (![dictionaryObject[kLDFlagConfigValueKeyVersion] isKindOfClass:[NSNumber class]]) { return NO; }

    return YES;
}

@end

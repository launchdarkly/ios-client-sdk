//
//  NSString+LDEventSource.m
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/31/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import "NSString+LDEventSource.h"

NSString *const LDEventSourceKeyValueDelimiter = @":";

NSString *const LDEventKeyData = @"data";
NSString *const LDEventKeyId = @"id";
NSString *const LDEventKeyEvent = @"event";
NSString *const LDEventKeyRetry = @"retry";

NSString * const LDEventSourceEventTerminator = @"\n\n";

@implementation NSString(LDEventSource)
-(NSArray<NSString*>*)lines {
    if (self.length == 0) {
        return nil;
    }
    return [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

-(BOOL)hasEventPrefix {
    return [self hasPrefix:[NSString stringWithFormat:@"%@%@", LDEventKeyEvent, LDEventSourceKeyValueDelimiter]]
        || [self hasPrefix:[NSString stringWithFormat:@"%@%@", LDEventKeyData, LDEventSourceKeyValueDelimiter]]
        || [self hasPrefix:[NSString stringWithFormat:@"%@%@", LDEventKeyId, LDEventSourceKeyValueDelimiter]]
        || [self hasPrefix:[NSString stringWithFormat:@"%@%@", LDEventKeyRetry, LDEventSourceKeyValueDelimiter]]
        || [self hasPrefix:LDEventSourceKeyValueDelimiter];
}

-(BOOL)hasEventTerminator {
    return [self containsString:LDEventSourceEventTerminator];
}
@end

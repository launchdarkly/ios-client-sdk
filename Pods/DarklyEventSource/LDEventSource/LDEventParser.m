//
//  LDEventParser.m
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/30/18. +JMJ
//  Copyright © 2018 Neil Cowburn. Portions copyright © Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDEventParser.h"
#import "LDEventSource.h"
#import "NSString+LDEventSource.h"
#import "NSArray+LDEventSource.h"

double MILLISEC_PER_SEC = 1000.0;

@interface LDEventParser()
@property (nonatomic, copy) NSString *eventString;
@property (nonatomic, strong) LDEvent *event;
@property (nonatomic, strong) NSNumber *retryInterval;
@property (nonatomic, copy) NSString *remainingEventString;
@end

@implementation LDEventParser
+(instancetype)eventParserWithEventString:(NSString*)eventString {
    return [[LDEventParser alloc] initWithEventString:eventString];
}

-(instancetype)initWithEventString:(NSString*)eventString {
    if (!(self = [super init])) {
        return nil;
    }

    self.eventString = eventString;
    [self parseEventString];

    return self;
}

-(void)parseEventString {
    if (self.eventString.length == 0) {
        return;
    }

    NSArray<NSString*> *linesToParse = [self linesToParseFromEventString];
    self.remainingEventString = [self remainingEventStringAfterParsingEventString];
    if (linesToParse.count == 0) { return; }

    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateOpen;

    for (NSString *line in linesToParse) {
        if ([line hasPrefix:LDEventSourceKeyValueDelimiter]) {
            continue;
        }

        if (line.length == 0) {
            self.event = event;
            return;
        }

        @autoreleasepool {
            NSScanner *scanner = [NSScanner scannerWithString:line];
            scanner.charactersToBeSkipped = [NSCharacterSet whitespaceCharacterSet];

            NSString *key, *value;
            [scanner scanUpToString:LDEventSourceKeyValueDelimiter intoString:&key];
            [scanner scanString:LDEventSourceKeyValueDelimiter intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&value];

            if (key && value) {
                if ([key isEqualToString:LDEventKeyEvent]) {
                    event.event = value;
                } else if ([key isEqualToString:LDEventKeyData]) {
                    if (event.data != nil) {
                        event.data = [event.data stringByAppendingFormat:@"\n%@", value];
                    } else {
                        event.data = value;
                    }
                } else if ([key isEqualToString:LDEventKeyId]) {
                    event.id = value;
                } else if ([key isEqualToString:LDEventKeyRetry]) {
                    NSCharacterSet *nonDigitCharacters = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
                    NSRange nonDigitRange = [value rangeOfCharacterFromSet:nonDigitCharacters];
                    if (nonDigitRange.location == NSNotFound) {
                        self.retryInterval = @([value integerValue]/MILLISEC_PER_SEC);
                    }
                }
            }
        }
    }
}

//extracts lines from the first thru the event terminator
-(nullable NSArray<NSString*>*)linesToParseFromEventString {
    if (self.eventString.length == 0) {
        return nil;
    }
    if (!self.eventString.hasEventTerminator) {
        return nil;
    }

    NSArray<NSString*> *eventStringParts = [self.eventString componentsSeparatedByString:LDEventSourceEventTerminator];
    if (eventStringParts.count == 0) {
        return nil;     //This should never happen because the guard for the terminator's presence passed...defensive
    }
    NSString *eventStringToParse = [eventStringParts.firstObject stringByAppendingString:LDEventSourceEventTerminator];

    return [eventStringToParse lines];
}

-(nullable NSString*)remainingEventStringAfterParsingEventString {
    if (self.eventString.length == 0) {
        return nil;
    }
    if (!self.eventString.hasEventTerminator) {
        return nil;
    }

    NSArray<NSString*> *eventStringParts = [self.eventString componentsSeparatedByString:LDEventSourceEventTerminator];
    if (eventStringParts.count < 2) {
        return nil;     //This should never happen because the guard for the terminator's presence passed...defensive
    }
    if (eventStringParts.count == 2 && eventStringParts[1].length == 0) {
        return nil;     //There is no remaining string after the terminator...this should be the normal exit
    }

    NSString *remainingEventString = [[eventStringParts subArrayFromIndex:1] componentsJoinedByString:LDEventSourceEventTerminator];
    if (remainingEventString.length == 0) {
        return nil;
    }

    return remainingEventString;
}
@end

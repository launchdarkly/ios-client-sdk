//
//  LDEventParser.m
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/30/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDEventParser.h"
#import "LDEventSource.h"
#import "NSString+LDEventSource.h"
#import "NSArray+LDEventSource.h"

static NSString *const ESKeyValueDelimiter = @":";

static NSString *const LDEventDataKey = @"data";
static NSString *const LDEventIDKey = @"id";
static NSString *const LDEventEventKey = @"event";
static NSString *const LDEventRetryKey = @"retry";

NSString * const kLDEventSourceEventTerminator = @"\n\n";

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
    if (!(self = [super init])) { return nil; }

    self.eventString = eventString;
    [self parseEventString];

    return self;
}

-(void)parseEventString {
    if (self.eventString.length == 0) { return; }

    NSArray<NSString*> *linesToParse = [self linesToParseFromEventString];
    self.remainingEventString = [self remainingEventStringAfterParsingEventString];
    if (linesToParse.count == 0) { return; }

    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateOpen;

    for (NSString *line in linesToParse) {
        if ([line hasPrefix:ESKeyValueDelimiter]) {
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
            [scanner scanUpToString:ESKeyValueDelimiter intoString:&key];
            [scanner scanString:ESKeyValueDelimiter intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&value];

            if (key && value) {
                if ([key isEqualToString:LDEventEventKey]) {
                    event.event = value;
                } else if ([key isEqualToString:LDEventDataKey]) {
                    if (event.data != nil) {
                        event.data = [event.data stringByAppendingFormat:@"\n%@", value];
                    } else {
                        event.data = value;
                    }
                } else if ([key isEqualToString:LDEventIDKey]) {
                    event.id = value;
                } else if ([key isEqualToString:LDEventRetryKey]) {
                    if ([value isKindOfClass:[NSNumber class]]) {
                        self.retryInterval = @([value doubleValue]);
                    }
                }
            }
        }
    }
}

//extracts lines from the first thru the event terminator
-(nullable NSArray<NSString*>*)linesToParseFromEventString {
    if (self.eventString.length == 0) { return nil; }
    if (![self.eventString containsString:kLDEventSourceEventTerminator]) { return nil; }

    NSArray<NSString*> *eventStringParts = [self.eventString componentsSeparatedByString:kLDEventSourceEventTerminator];
    if (eventStringParts.count == 0) { return nil; }    //This should never happen because the guard for the terminator's presence passed...defensive
    NSString *eventStringToParse = [eventStringParts.firstObject stringByAppendingString:kLDEventSourceEventTerminator];

    return [eventStringToParse lines];
}

-(nullable NSString*)remainingEventStringAfterParsingEventString {
    if (self.eventString.length == 0) { return nil; }
    if (![self.eventString containsString:kLDEventSourceEventTerminator]) { return self.eventString; }

    NSArray<NSString*> *eventStringParts = [self.eventString componentsSeparatedByString:kLDEventSourceEventTerminator];
    if (eventStringParts.count < 2) { return nil; }     //This should never happen because the guard for the terminator's presence passed...defensive
    if (eventStringParts.count == 2 && eventStringParts[1].length == 0) { return nil; } //There is no remaining string after the terminator...this should be the normal exit

    NSArray<NSString*> *remainingEventStringParts = [eventStringParts subArrayFromIndex:1];
    NSPredicate *nonemptyStringPredicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if (![evaluatedObject isKindOfClass:[NSString class]]) { return NO; }
        NSString *evaluatedString = evaluatedObject;
        return evaluatedString.length > 0;
    }];
    NSArray<NSString*> *nonEmptyRemainingEventStringParts = [remainingEventStringParts filteredArrayUsingPredicate:nonemptyStringPredicate];
    NSString *remainingEventString = [nonEmptyRemainingEventStringParts componentsJoinedByString:kLDEventSourceEventTerminator];
    if (remainingEventString.length == 0) {
        return nil;
    }

    return remainingEventString;
}
@end

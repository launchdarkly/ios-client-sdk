//
//  LDEvent+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDEvent+Testable.h"
#import "LDEvent+EventTypes.h"
#import "DarklyConstants.h"
#import "NSJSONSerialization+Testable.h"
#import "NSDictionary+JSON.h"

@implementation LDEvent(Testable)
+(instancetype)stubPingEvent{
    LDEvent *event = [LDEvent new];
    event.event = kLDEventTypePing;
    event.readyState = kEventStateOpen;
    return event;
}

+(instancetype)stubEvent:(NSString*)eventType fromJsonFileNamed:(NSString*)fileName {
    LDEvent *event = [LDEvent new];
    event.event = eventType;
    event.readyState = kEventStateOpen;
    event.data = [NSJSONSerialization jsonStringFromFileNamed:fileName];
    return event;
}

+(instancetype)stubEvent:(NSString*)eventType withDataDictionary:(NSDictionary*)dataDictionary {
    LDEvent *event = [LDEvent new];
    event.event = eventType;
    event.readyState = kEventStateOpen;
    event.data = [dataDictionary jsonString];
    return event;
}

+(instancetype)stubUnauthorizedEvent {
    NSError *error = [NSError errorWithDomain:LDEventSourceErrorDomain code:kErrorCodeUnauthorized userInfo:nil];
    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateClosed;
    event.error = error;
    return event;
}

+(instancetype)stubErrorEvent {
    NSError *error = [NSError errorWithDomain:@"" code:2 userInfo:nil];
    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateClosed;
    event.error = error;
    return event;
}
@end

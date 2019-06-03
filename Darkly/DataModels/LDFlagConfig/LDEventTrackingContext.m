//
//  LDEventTrackingContext.m
//  Darkly
//
//  Created by Mark Pokorny on 5/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventTrackingContext.h"
#import "NSDate+ReferencedDate.h"
#import "NSNumber+LaunchDarkly.h"

NSString * const kLDEventTrackingContextKeyTrackEvents = @"trackEvents";
NSString * const kLDEventTrackingContextKeyDebugEventsUntilDate = @"debugEventsUntilDate";

@implementation LDEventTrackingContext
+(instancetype)contextWithObject:(id)object {
    return [[LDEventTrackingContext alloc] initWithObject:object];
}

-(instancetype)initWithObject:(id)object {
    if (!object || ![object isKindOfClass:[NSDictionary class]]) { return nil; }
    NSDictionary *dictionary = object;
    if (!dictionary[kLDEventTrackingContextKeyTrackEvents]) { return nil; }
    if (![dictionary[kLDEventTrackingContextKeyTrackEvents] isKindOfClass:[NSNumber class]]) { return nil; }
    if (!(self = [super init])) { return nil; }

    self.trackEvents = [dictionary[kLDEventTrackingContextKeyTrackEvents] boolValue];
    if (dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] && [dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] isKindOfClass:[NSNumber class]]) {
        self.debugEventsUntilDate = [NSDate dateFromMillisSince1970:[dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] ldMillisecondValue]];
    }

    return self;
}

-(NSDictionary*)dictionaryValue {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:2];
    dictionary[kLDEventTrackingContextKeyTrackEvents] = @(self.trackEvents);
    if (self.debugEventsUntilDate) {
        dictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] = @([self.debugEventsUntilDate millisSince1970]);
    }
    return [NSDictionary dictionaryWithDictionary:dictionary];
}

-(void)encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeBool:self.trackEvents forKey:kLDEventTrackingContextKeyTrackEvents];
    [encoder encodeObject:self.debugEventsUntilDate forKey:kLDEventTrackingContextKeyDebugEventsUntilDate];
}

-(instancetype)initWithCoder:(NSCoder*)decoder {
    if (!(self = [super init])) { return nil; }

    self.trackEvents = [decoder decodeBoolForKey:kLDEventTrackingContextKeyTrackEvents];
    self.debugEventsUntilDate = [decoder decodeObjectForKey:kLDEventTrackingContextKeyDebugEventsUntilDate];

    return self;
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<LDEventTrackingContext: %p, trackEvents: %@, debugEventsUntilDate: %@>", self, self.trackEvents ? @"YES" : @"NO", self.debugEventsUntilDate ?: @"nil"];
}

-(id)copyWithZone:(NSZone*)zone {
    LDEventTrackingContext *copiedContext = [[self class] new];
    copiedContext.trackEvents = self.trackEvents;
    copiedContext.debugEventsUntilDate = [self.debugEventsUntilDate copy];  //This may not return a different object, NSDate may be treated more like a value-type
    return copiedContext;
}
@end

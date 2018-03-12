//
//  LDEvent+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <DarklyEventSource/LDEventSource.h>

@interface LDEvent(Testable)
+(nonnull instancetype)stubPingEvent;
+(nonnull instancetype)stubEvent:(nonnull NSString*)eventType fromJsonFileNamed:(nonnull NSString*)fileName;
+(nonnull instancetype)stubEvent:(nonnull NSString*)eventType withDataDictionary:(nonnull NSDictionary*)dataDictionary;
+(nonnull instancetype)stubUnauthorizedEvent;
+(nonnull instancetype)stubErrorEvent;
@end

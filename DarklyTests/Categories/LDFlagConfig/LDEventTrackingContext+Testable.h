//
//  LDEventTrackingContext+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 5/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventTrackingContext.h"

@interface LDEventTrackingContext(Testable)
+(instancetype)contextWithTrackEvents:(BOOL)trackEvents debugEventsUntilDate:(NSDate*)debugEventsUntilDate;
-(instancetype)initWithTrackEvents:(BOOL)trackEvents debugEventsUntilDate:(NSDate*)debugEventsUntilDate;
-(BOOL)isEqualToContext:(LDEventTrackingContext*)otherContext;
-(BOOL)isEqual:(id)other;
@end

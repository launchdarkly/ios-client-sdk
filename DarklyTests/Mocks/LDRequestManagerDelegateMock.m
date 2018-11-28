//
//  LDRequestManagerDelegateMock.m
//  DarklyTests
//
//  Created by Mark Pokorny on 9/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDRequestManagerDelegateMock.h"

@implementation LDRequestManagerDelegateMock
-(void)processedEvents:(BOOL)success jsonEventArray:(nonnull NSArray*)jsonEventArray responseDate:(nullable NSDate*)responseDate {
    self.processedEventsCallCount += 1;
    self.processedEventsSuccess = success;
    self.processedEventsJsonEventArray = jsonEventArray;
    self.processedEventsResponseDate = responseDate;
    if (self.processedEventsCallback) {
        self.processedEventsCallback();
    }
}

-(void)processedConfig:(BOOL)success jsonConfigDictionary:(nullable NSDictionary*)jsonConfigDictionary {
    self.processedConfigCallCount += 1;
    self.processedConfigSuccess = success;
    self.processedConfigJsonConfigDictionary = jsonConfigDictionary;
    if (self.processedConfigCallback) {
        self.processedConfigCallback();
    }
}
@end

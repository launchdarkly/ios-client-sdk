//
//  LDDataAccumulator.h
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/30/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDEventStringAccumulator : NSObject
@property (nonatomic, copy) NSString *eventString;

-(void)accumulateEventStringWithString:(NSString*)eventString;
-(BOOL)isReadyToParseEvent;
-(void)reset;
@end

//
//  LDEventParser.h
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/30/18. +JMJ
//  Copyright © 2018 Neil Cowburn. Portions copyright © Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDEvent;

@interface LDEventParser : NSObject
@property (nonatomic, copy, readonly) NSString *eventString;
@property (nonatomic, strong, readonly) LDEvent *event;
@property (nonatomic, strong, readonly) NSNumber *retryInterval;
@property (nonatomic, copy, readonly) NSString *remainingEventString;

+(instancetype)eventParserWithEventString:(NSString*)eventString;
-(instancetype)initWithEventString:(NSString*)eventString;
@end

//
//  NSString+LDEventSource.h
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/31/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const LDEventSourceKeyValueDelimiter;
extern NSString *const LDEventSourceEventTerminator;

extern NSString *const LDEventKeyData;
extern NSString *const LDEventKeyId;
extern NSString *const LDEventKeyEvent;
extern NSString *const LDEventKeyRetry;

@interface NSString(LDEventSource)
@property (nonatomic, readonly, assign) BOOL hasEventPrefix;
@property (nonatomic, readonly, assign) BOOL hasEventTerminator;
-(NSArray<NSString*>*)lines;
@end

//
//  LDRequestManagerDelegateMock.h
//  DarklyTests
//
//  Created by Mark Pokorny on 9/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDRequestManager.h"

@interface LDRequestManagerDelegateMock : NSObject <RequestManagerDelegate>
@property (nonatomic, assign) NSInteger processedEventsCallCount;
@property (nonatomic, assign) BOOL processedEventsSuccess;
@property (nonatomic, strong, nullable) NSArray *processedEventsJsonEventArray;
@property (nonatomic, strong, nullable) NSDate *processedEventsResponseDate;
@property (nonatomic, strong) void (^ _Nullable processedEventsCallback)(void);
-(void)processedEvents:(BOOL)success jsonEventArray:(nonnull NSArray*)jsonEventArray responseDate:(nullable NSDate*)responseDate;

@property (nonatomic, assign) NSInteger processedConfigCallCount;
@property (nonatomic, assign) BOOL processedConfigSuccess;
@property (nonatomic, strong, nullable) NSDictionary *processedConfigJsonConfigDictionary;
@property (nonatomic, strong) void (^ _Nullable processedConfigCallback)(void);
-(void)processedConfig:(BOOL)success jsonConfigDictionary:(nullable NSDictionary*)jsonConfigDictionary;
@end

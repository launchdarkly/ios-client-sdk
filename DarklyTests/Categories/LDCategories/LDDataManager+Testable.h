//
//  LDDataManager+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDDataManager.h"

extern int kUserCacheSize;

@interface LDDataManager(Testable)
@property (strong, atomic) NSMutableArray *eventsArray;
@property (nonatomic, strong) dispatch_queue_t eventsQueue;
@property (nonatomic, strong) dispatch_queue_t saveUserQueue;
@end

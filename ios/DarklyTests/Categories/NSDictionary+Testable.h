//
//  NSDictionary+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+Testable.h"

@interface NSDictionary(Testable)
-(BOOL)boolValueForKey:(nullable NSString*)key;
-(NSInteger)integerValueForKey:(nullable NSString*)key;
@end

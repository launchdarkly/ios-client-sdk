//
//  NSObject+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject(Testable)
-(BOOL)boolValue;
-(NSInteger)integerValue;
@end

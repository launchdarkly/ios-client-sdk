//
//  NSDateFormatter+JsonHeader+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 5/8/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kDateHeaderValueDate;

@interface NSDateFormatter(JsonHeader_Testable)
+(NSDate*)eventDateHeaderStub;
@end

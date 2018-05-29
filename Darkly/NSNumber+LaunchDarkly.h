//
//  NSNumber+LaunchDarkly.h
//  Darkly
//
//  Created by Mark Pokorny on 5/29/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDate+ReferencedDate.h"

@interface NSNumber(LaunchDarkly)
-(LDMillisecond)ldMillisecondValue;
@end

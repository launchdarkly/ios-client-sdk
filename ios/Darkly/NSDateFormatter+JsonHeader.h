//
//  NSDateFormatter+JsonHeader.h
//  Darkly
//
//  Created by Mark Pokorny on 5/8/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDateFormatter(JsonHeader)
+(instancetype)jsonHeaderDateFormatter;
@end

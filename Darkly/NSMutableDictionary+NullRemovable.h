//
//  NSMutableDictionary+NullRemovable.h
//  Darkly
//
//  Created by Mark Pokorny on 7/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (NullRemovable)
-(NSMutableDictionary *)removeNullValues;
@end

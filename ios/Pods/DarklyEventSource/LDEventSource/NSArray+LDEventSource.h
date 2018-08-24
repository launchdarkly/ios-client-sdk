//
//  NSArray+LDEventSource.h
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/31/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray(LDEventSource)
-(NSUInteger)indexOfFirstEmptyLine;
//Returns the array beyond the index, or nil if the index is at the end of the array or beyond
-(NSArray*)subArrayFromIndex:(NSUInteger)index;
@end

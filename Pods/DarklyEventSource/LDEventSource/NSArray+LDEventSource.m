//
//  NSArray+LDEventSource.m
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/31/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSArray+LDEventSource.h"

@implementation NSArray(LDEventSource)
-(NSUInteger)indexOfFirstEmptyLine {
    if (![self.firstObject isKindOfClass:[NSString class]]) {
        return NSNotFound;
    }
    return [self indexOfObject:@""];
}
-(NSArray*)subArrayFromIndex:(NSUInteger)index {
    if (index > (self.count - 1)) {
        return nil;     //index is beyond the last element
    }
    return [self subarrayWithRange:NSMakeRange(index, self.count - index)];
}
@end

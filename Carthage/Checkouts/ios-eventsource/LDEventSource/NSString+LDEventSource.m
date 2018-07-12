//
//  NSString+LDEventSource.m
//  DarklyEventSource
//
//  Created by Mark Pokorny on 5/31/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

#import "NSString+LDEventSource.h"

@implementation NSString(LDEventSource)
-(NSArray<NSString*>*)lines {
    if (self.length == 0) { return nil; }
    return [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}
@end

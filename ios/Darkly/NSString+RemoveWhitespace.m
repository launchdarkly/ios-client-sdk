//
//  NSString+RemoveWhitespace.m
//  Darkly
//
//  Created by Mark Pokorny on 7/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "NSString+RemoveWhitespace.h"

//Idea from https://stackoverflow.com/questions/7628470/remove-all-whitespaces-from-nsstring
@implementation NSString (RemoveWhitespace)
-(NSString*)stringByRemovingWhitespace {
    return [[self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
}
@end

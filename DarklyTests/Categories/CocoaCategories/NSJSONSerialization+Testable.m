//
//  TestUtilities.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSJSONSerialization+Testable.h"

@implementation NSJSONSerialization(Testable)
+(id)jsonObjectFromFileNamed:(NSString*)fileName {
    NSString *filepath = [NSJSONSerialization filepathFromFileNamed:fileName];
    if (filepath.length == 0) { return nil; }
    return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filepath] options:kNilOptions error:nil];
}

+(NSString*)jsonStringFromFileNamed:(NSString*)fileName {
    NSString *filepath = [NSJSONSerialization filepathFromFileNamed:fileName];
    if (filepath.length == 0) { return nil; }
    return [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
}

+(NSString*)filepathFromFileNamed:(NSString*)fileName {
    NSString *filepath;
    for (NSBundle *bundle in [NSBundle allBundles]) {
        filepath = [bundle pathForResource:fileName ofType:@"json"];
        if (filepath) { break; }
    }
    return filepath;
}
@end

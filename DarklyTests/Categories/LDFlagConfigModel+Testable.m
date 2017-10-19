//
//  LDFlagConfigModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"

@implementation LDFlagConfigModel(Testable)
+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName {
    NSString *filepath;
    for (NSBundle *bundle in [[NSBundle allBundles] copy]) {
        filepath = [bundle pathForResource:fileName ofType:@"json"];
        if (filepath) { break; }
    }
    if (!filepath) { return nil; }
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    if (!data) { return nil; }
    NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    return [[LDFlagConfigModel alloc] initWithDictionary:jsonDictionary];
}
@end

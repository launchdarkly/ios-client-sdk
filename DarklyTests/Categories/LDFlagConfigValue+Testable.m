//
//  LDFlagConfigValue+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigValue+Testable.h"
#import "NSJSONSerialization+Testable.h"

@implementation LDFlagConfigValue(Testable)
+(instancetype)flagConfigValueFromJsonFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:fileName];
    return [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[flagKey]];
}
@end

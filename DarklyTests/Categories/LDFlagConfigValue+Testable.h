//
//  LDFlagConfigValue+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LDFlagConfigValue.h"

@interface LDFlagConfigValue(Testable)
+(instancetype)flagConfigValueFromJsonFileNamed:(NSString*)fileName flagKey:(NSString*)flagKey;
+(NSArray<LDFlagConfigValue*>*)stubFlagConfigValuesForFlagKey:(NSString*)flagKey;
+(id)defaultValueForFlagKey:(NSString*)flagKey;
@end

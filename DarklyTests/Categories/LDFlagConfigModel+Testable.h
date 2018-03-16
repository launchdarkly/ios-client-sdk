//
//  LDFlagConfigModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDFlagConfigModel(Testable)
+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName;
+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version;
+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key;
+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version;
+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key;
@end

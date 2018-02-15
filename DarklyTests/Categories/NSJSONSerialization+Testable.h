//
//  NSJSONSerialization+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 1/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSJSONSerialization(Testable)
+(nullable id)jsonObjectFromFileNamed:(nonnull NSString*)fileName;
+(nullable NSString*)jsonStringFromFileNamed:(nonnull NSString*)fileName;
@end

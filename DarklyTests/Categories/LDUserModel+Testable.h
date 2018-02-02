//
//  LDUserModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 1/9/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDUserModel (Testable)
/**
 -[LDUserModel dictionaryValueWithFlags: includePrivateAttributes: config:] intentionally omits the private attributes LIST from the dictionary when includePrivateAttributes == YES to satisfy an LD server requirement. This method allows control over including that list for testing.
 */
-(NSDictionary *)dictionaryValueWithFlags:(BOOL)includeFlags includePrivateAttributes:(BOOL)includePrivate config:(LDConfig*)config includePrivateAttributeList:(BOOL)includePrivateList;
@end

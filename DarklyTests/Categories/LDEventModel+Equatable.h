//
//  LDEventModel+Equatable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/11/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDEventModel(Equatable)
-(BOOL)isEqual:(id)object;
@end

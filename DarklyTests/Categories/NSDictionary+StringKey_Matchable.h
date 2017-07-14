//
//  NSDictionary+StringKey_Matchable.h
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary(StringKey_Matchable)
-(NSArray*)keysWithDifferentValuesIn:(id)object;
@end


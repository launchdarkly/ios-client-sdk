//
//  LDUserModel+Equatable.h
//  Darkly
//
//  Created by Mark Pokorny on 7/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDUserModel (Equatable)
-(BOOL) isEqual:(id)object ignoringProperties:(NSArray<NSString*>*)ignoredProperties;
@end

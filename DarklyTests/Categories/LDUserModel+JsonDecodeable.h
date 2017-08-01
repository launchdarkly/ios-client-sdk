//
//  LDUserModel+JsonDecodeable.h
//  Darkly
//
//  Created by Mark Pokorny on 7/27/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDUserModel (JsonDecodeable)
+(LDUserModel*)userFrom:(NSString*)jsonUser;
@end

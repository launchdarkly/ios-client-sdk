//
//  NSHTTPURLResponse+Unauthorized.h
//  Darkly
//
//  Created by Mark Pokorny on 10/16/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSHTTPURLResponse(Unauthorized)
-(BOOL)isUnauthorizedHTTPResponse;
@end

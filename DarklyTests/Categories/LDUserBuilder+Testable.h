//
//  LDUserBuilder+Testable.h
//  Darkly
//
//  Created by Mark Pokorny on 8/2/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@interface LDUserBuilder (Testable)
+ (instancetype)userBuilderWithKey:(NSString*)key;
@end

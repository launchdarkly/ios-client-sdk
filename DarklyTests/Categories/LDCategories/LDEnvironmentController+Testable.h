//
//  LDEnvironmentController+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 9/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEnvironmentController.h"

@interface LDEnvironmentController (Testable)
@property (nonatomic, weak) LDDataManager *dataManager;
@property (nonatomic, strong) LDUserModel *user;
@property(nonatomic, strong) LDRequestManager *requestManager;
@property(nonatomic, strong) NSDate *backgroundTime;
@end

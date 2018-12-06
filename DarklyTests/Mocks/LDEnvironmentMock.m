//
//  LDEnvironmentMock.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEnvironmentMock.h"
#import "LDConfig.h"
#import "NSString+LaunchDarkly.h"

@implementation LDEnvironmentMock
+(instancetype)environmentMockForMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user {
    LDEnvironmentMock *environmentMock = [[LDEnvironmentMock alloc] init];
    environmentMock.environmentMockCalledValueMobileKey = mobileKey;
    environmentMock.environmentMockCalledValueConfig = config;
    environmentMock.environmentMockCalledValueUser = user;
    environmentMock.reportFlushResult = YES;

    return environmentMock;
}

-(void)start {
    self.startCallCount += 1;
}

-(void)stop {
    self.stopCallCount += 1;
}

-(void)setOnline:(BOOL)online {
    self.setOnlineCalledValueOnline = online;
    self.setOnlineCallCount += 1;
}

-(void)updateUser:(LDUserModel*)newUser {
    self.updateUserCalledValueNewUser = newUser;
    self.updateUserCallCount += 1;
}

-(BOOL)isOnline {
    return self.reportOnline;
}

-(BOOL)flush {
    self.flushCallCount += 1;
    return YES;
}

-(NSString*)description {
    NSString *description = [NSString stringWithFormat:@"<LDEnvironmentMock:%p", self];
    description = [NSString stringWithFormat:@"%@ [environmentMockCall mobileKey:%@", description, self.environmentMockCalledValueMobileKey];
    NSString *configDescription = [NSString stringWithFormat:@"(mobileKey:%@ secondaryMobileKeys:%@)", self.environmentMockCalledValueConfig.mobileKey,
                                   [self.environmentMockCalledValueConfig secondaryMobileKeysDescription]];
    description = [NSString stringWithFormat:@"%@ config:%@", description, configDescription];
    description = [NSString stringWithFormat:@"%@ user-key:%@", description, self.environmentMockCalledValueUser.key];
    description = [NSString stringWithFormat:@"%@ callCount:%ld]", description, self.environmentMockCallCount];
    description = [NSString stringWithFormat:@"%@ [setOnlineCall-online:%@", description, [NSString stringWithBool:self.setOnlineCalledValueOnline]];
    description = [NSString stringWithFormat:@"%@ callCount:%ld]", description, self.setOnlineCallCount];

    description = [NSString stringWithFormat:@"%@>", description];
    return description;
}
@end

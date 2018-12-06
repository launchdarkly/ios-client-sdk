//
//  LDEnvironmentMock.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEnvironment.h"

NS_ASSUME_NONNULL_BEGIN

@interface LDEnvironmentMock : LDEnvironment
@property (nonatomic, copy) NSString *environmentMockCalledValueMobileKey;
@property (nonatomic, strong) LDConfig *environmentMockCalledValueConfig;
@property (nonatomic, strong) LDUserModel *environmentMockCalledValueUser;
@property (nonatomic, assign) NSUInteger environmentMockCallCount;
+(instancetype)environmentMockForMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user;
@property (nonatomic, assign) NSUInteger startCallCount;
-(void)start;
@property (nonatomic, assign) NSUInteger stopCallCount;
-(void)stop;
@property (nonatomic, assign) BOOL setOnlineCalledValueOnline;
@property (nonatomic, assign) NSUInteger setOnlineCallCount;
-(void)setOnline:(BOOL)online;
@property (nonatomic, strong) LDUserModel *updateUserCalledValueNewUser;
@property (nonatomic, assign) NSUInteger updateUserCallCount;
-(void)updateUser:(LDUserModel*)newUser;
@property (nonatomic, assign) BOOL reportOnline;
-(BOOL)isOnline;
@property (nonatomic, assign) NSUInteger flushCallCount;
@property (nonatomic, assign) BOOL reportFlushResult;
-(BOOL)flush;
@end

NS_ASSUME_NONNULL_END

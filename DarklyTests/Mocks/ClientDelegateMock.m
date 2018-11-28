//
//  ClientDelegateMock.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "ClientDelegateMock.h"

@implementation ClientDelegateMock

+(instancetype)clientDelegateMock {
    return [[ClientDelegateMock alloc] init];
}

-(instancetype)init {
    self = [super init];

    return self;
}

-(void)userDidUpdate {
    self.userDidUpdateCallCount = [self processCallbackWithCount:self.userDidUpdateCallCount block:self.userDidUpdateCallback];
}

-(void)userUnchanged {
    self.userUnchangedCallCount = [self processCallbackWithCount:self.userUnchangedCallCount block:self.userUnchangedCallback];
}

-(void)featureFlagDidUpdate:(NSString *)key {
    self.featureFlagDidUpdateCallCount += 1;
    if (self.featureFlagDidUpdateCallback == nil) { return; }
    self.featureFlagDidUpdateCallback(key);
}

-(void)serverConnectionUnavailable {
    self.serverConnectionUnavailableCallCount = [self processCallbackWithCount:self.serverConnectionUnavailableCallCount block:self.serverUnavailableCallback];
}

-(NSInteger)processCallbackWithCount:(NSInteger)callbackCount block:(MockLDEnvironmentDelegateCallbackBlock)callbackBlock {
    callbackCount += 1;
    if (!callbackBlock) { return callbackCount; }
    callbackBlock();
    return callbackCount;
}

@end

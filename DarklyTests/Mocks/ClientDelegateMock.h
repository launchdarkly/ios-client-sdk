//
//  ClientDelegateMock.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/25/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDClient.h"

typedef void(^MockLDEnvironmentDelegateCallbackBlock)(void);
typedef void(^MockLDEnvironmentDelegateFeatureFlagDidUpdateCallbackBlock)(NSString* flagKey);

@interface ClientDelegateMock: NSObject <ClientDelegate>

@property (nonatomic, assign) NSInteger userDidUpdateCallCount;
@property (nonatomic, assign) NSInteger userUnchangedCallCount;
@property (nonatomic, assign) NSInteger featureFlagDidUpdateCallCount;
@property (nonatomic, assign) NSInteger serverConnectionUnavailableCallCount;
@property (nonatomic, strong) MockLDEnvironmentDelegateCallbackBlock userDidUpdateCallback;
@property (nonatomic, strong) MockLDEnvironmentDelegateCallbackBlock userUnchangedCallback;
@property (nonatomic, strong) MockLDEnvironmentDelegateFeatureFlagDidUpdateCallbackBlock featureFlagDidUpdateCallback;
@property (nonatomic, strong) MockLDEnvironmentDelegateCallbackBlock serverUnavailableCallback;

+(instancetype)clientDelegateMock;
@end

//
//  LDEventModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventModel+Testable.h"
#import "LDEventModel.h"
#import "LDUserModel+Stub.h"

NSString * const kFeatureEventKeyStub = @"LDEventModel.featureEvent.key";
NSString * const kCustomEventKeyStub = @"LDEventModel.customEvent.key";
NSString * const kCustomEventCustomDataKeyStub = @"LDEventModel.customEventCustomData.key";
NSString * const kCustomEventCustomDataValueStub = @"LDEventModel.customEventCustomData.value";
const double featureEventValueStub = 3.14159;
const double featureEventDefaultValueStub = 2.71828;

@implementation LDEventModel (Testable)
+(instancetype)stubEventWithKind:(NSString*)eventKind user:(nullable LDUserModel*)user config:(nullable LDConfig*)config {
    if (!user) {
        user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    }
    BOOL inlineUser = config ? config.inlineUserInEvents : false;
    if ([eventKind isEqualToString:kEventModelKindFeature]) {
        return [LDEventModel featureEventWithFlagKey:kFeatureEventKeyStub
                                        flagValue:@(featureEventValueStub)
                                 defaultFlagValue:@(featureEventDefaultValueStub)
                                       userValue:user
                                      inlineUser:inlineUser];
    }
    if ([eventKind isEqualToString:kEventModelKindCustom]) {
        return [LDEventModel customEventWithKey:kCustomEventKeyStub
                              customData:@{kCustomEventCustomDataKeyStub: kCustomEventCustomDataValueStub}
                                      userValue:user
                                     inlineUser:inlineUser];
    }

    return [LDEventModel identifyEventWithUser:user];
}
@end

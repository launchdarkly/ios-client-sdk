//
//  LDUserEnvironment+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDUserEnvironment+Testable.h"
#import "LDUserModel+Testable.h"
#import "LDEventTrackingContext.h"
#import "LDFlagConfigModel+Testable.h"

NSString *const kEnvironmentKeyPrimary = @"com.launchdarkly.DarklyTest.mobileKey.A";
NSString *const kEnvironmentKeySecondaryB = @"com.launchdarkly.DarklyTest.mobileKey.B";
NSString *const kEnvironmentKeySecondaryC = @"com.launchdarkly.DarklyTest.mobileKey.C";
NSString *const kEnvironmentKeySecondaryD = @"com.launchdarkly.DarklyTest.mobileKey.D";
NSString *const kEnvironmentKeySecondaryE = @"com.launchdarkly.DarklyTest.mobileKey.E";

@implementation LDUserEnvironment (Testable)
@dynamic userKey;
@dynamic users;

+(NSDictionary<NSString*, LDUserModel*>*)stubUserModelsForUserWithKey:(NSString*)userKey environmentKeys:(NSArray<NSString*>*)environmentKeys {
    NSMutableDictionary<NSString*, LDUserModel*> *users = [NSMutableDictionary dictionaryWithCapacity:environmentKeys.count];
    LDUserModel *baseUser = [LDUserModel stubWithKey:userKey];
    for (NSString *environmentKey in environmentKeys) {
        LDUserModel *userWithFlagConfigForEnvironment = [baseUser copy];
        LDFlagConfigModel *flagConfigForEnvironment = [LDFlagConfigModel flagConfigFromJsonFileNamed:LDUserEnvironment.flagConfigFilenames[environmentKey]
                                                                                eventTrackingContext:[[LDEventTrackingContext alloc] init]];
        userWithFlagConfigForEnvironment.flagConfig = flagConfigForEnvironment;
        users[environmentKey] = userWithFlagConfigForEnvironment;
    }

    return [users copy];
}

+(NSArray<NSString*>*)environmentKeys {
    return @[kEnvironmentKeyPrimary, kEnvironmentKeySecondaryB, kEnvironmentKeySecondaryC, kEnvironmentKeySecondaryD, kEnvironmentKeySecondaryE];
}

+(NSDictionary<NSString*, NSString*>*)flagConfigFilenames {
    return @{kEnvironmentKeyPrimary: @"featureFlags",
             kEnvironmentKeySecondaryB: @"emptyConfig",
             kEnvironmentKeySecondaryC: @"ldEnvironmentControllerTestConfigA",
             kEnvironmentKeySecondaryD: @"ldFlagConfigModelTest",
             kEnvironmentKeySecondaryE: @"dictionaryConfigIsADictionary-3Key"};
}

+(NSDictionary<NSString*, LDUserEnvironment*>*)stubUserEnvironmentsForUsersWithKeys:(NSArray<NSString*>*)userKeys {
    return [LDUserEnvironment stubUserEnvironmentsForUsersWithKeys:userKeys mobileKeys:LDUserEnvironment.environmentKeys];
}

+(NSDictionary<NSString*, LDUserEnvironment*>*)stubUserEnvironmentsForUsersWithKeys:(NSArray<NSString*>*)userKeys mobileKeys:(NSArray<NSString*>*)mobileKeys {
    NSMutableDictionary *userEnvironments = [NSMutableDictionary dictionaryWithCapacity:userKeys.count];
    for (NSString *userKey in userKeys) {
        NSDictionary<NSString*, LDUserModel*> *userModels = [LDUserEnvironment stubUserModelsForUserWithKey:userKey environmentKeys:mobileKeys];
        userEnvironments[userKey] = [LDUserEnvironment userEnvironmentForUserWithKey:userKey environments:userModels];
    }

    return userEnvironments;
}

-(BOOL)isEqualToUserEnvironment:(LDUserEnvironment*)otherUserEnvironment {
    if (![self.userKey isEqualToString:otherUserEnvironment.userKey]) { return NO; }
    if (self.users.count != otherUserEnvironment.users.count) { return NO; }
    for (NSString *environmentKey in self.users.allKeys) {
        LDUserModel *userForEnvironment = self.users[environmentKey];
        LDUserModel *otherUserForEnvironment = otherUserEnvironment.users[environmentKey];
        if (![userForEnvironment isEqual:otherUserForEnvironment ignoringAttributes:@[kUserAttributeUpdatedAt]]) { return NO; }
    }
    return YES;
}

@end

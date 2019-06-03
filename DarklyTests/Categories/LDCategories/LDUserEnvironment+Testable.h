//
//  LDUserEnvironment+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 10/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDUserEnvironment.h"

extern NSString *const kEnvironmentKeyPrimary;
extern NSString *const kEnvironmentKeySecondaryB;
extern NSString *const kEnvironmentKeySecondaryC;
extern NSString *const kEnvironmentKeySecondaryD;
extern NSString *const kEnvironmentKeySecondaryE;

@interface LDUserEnvironment (Testable)
@property (nonatomic, strong) NSString *userKey;
@property (nonatomic, strong) NSDictionary<NSString*, LDUserModel*> *users;
@property (nonatomic, strong, class, readonly) NSArray<NSString*> *environmentKeys;
@property (nonatomic, strong, class, readonly) NSDictionary<NSString*, NSString*> *flagConfigFilenames;

+(NSDictionary<NSString*, LDUserModel*>*)stubUserModelsForUserWithKey:(NSString*)userKey environmentKeys:(NSArray<NSString*>*)environmentKeys;
+(NSArray<NSString*>*)environmentKeys;
+(NSDictionary<NSString*, NSString*>*)flagConfigFilenames;
+(NSDictionary<NSString*, LDUserEnvironment*>*)stubUserEnvironmentsForUsersWithKeys:(NSArray<NSString*>*)userKeys;
+(NSDictionary<NSString*, LDUserEnvironment*>*)stubUserEnvironmentsForUsersWithKeys:(NSArray<NSString*>*)userKeys mobileKeys:(NSArray<NSString*>*)mobileKeys;
-(BOOL)isEqualToUserEnvironment:(LDUserEnvironment*)otherUserEnvironment;

@end

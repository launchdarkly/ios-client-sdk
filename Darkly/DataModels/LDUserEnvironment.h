//
//  LDUserEnvironment.h
//  Darkly
//
//  Created by Mark Pokorny on 10/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDUserModel;

//Wrapper data object used for caching environment based users. Conceptually, an object containing a collection of feature flags for a single user keyed on mobile-key
@interface LDUserEnvironment: NSObject <NSCoding>
@property (nonatomic, strong, readonly, nonnull) NSString *userKey;
@property (nonatomic, strong, readonly, nullable) NSDate *lastUpdated;

//Each LDUserModel passed in through environments must match the userKey in order to be included. Any that do not match will not be included.
+(nullable instancetype)userEnvironmentForUserWithKey:(nonnull NSString*)userKey environments:(nullable NSDictionary<NSString*, LDUserModel*>*)environments;
-(nullable instancetype)initForUserWithKey:(nonnull NSString*)userKey environments:(nonnull NSDictionary<NSString*, LDUserModel*>*)environments;

-(nullable instancetype)initWithCoder:(NSCoder*)coder;
-(void)encodeWithCoder:(NSCoder*)coder;

-(nullable instancetype)initWithDictionary:(nullable NSDictionary*)dictionary;
-(nullable NSDictionary*)dictionaryValue;

-(nullable LDUserModel*)userForMobileKey:(nonnull NSString*)mobileKey;
-(void)setUser:(nonnull LDUserModel*)user mobileKey:(nonnull NSString*)mobileKey;
-(void)removeUserForMobileKey:(nonnull NSString*)mobileKey;

@end

//
//  LDEnvironment.h
//  Darkly
//
//  Created by Mark Pokorny on 10/3/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDClient.h"
#import "LDConfig.h"
#import "LDUserModel.h"
#import "LDClientInterface.h"

@interface LDEnvironment: NSObject<LDClientInterface>

@property (nonatomic, copy, readonly) NSString *mobileKey;
@property (nonatomic, strong, readonly) LDConfig *config;
@property (nonatomic, strong, readonly) LDUserModel *user;
@property (nonatomic, assign, getter=isStarted, readonly) BOOL start;
@property (nonatomic, assign, getter=isOnline) BOOL online;
@property (nonatomic, weak) id<ClientDelegate> delegate;
@property (nonatomic, strong, readonly) NSDictionary<NSString*, id> *allFlags;
@property (nonatomic, assign, readonly) BOOL isPrimary;
@property (nonatomic, copy, readonly) NSString *environmentName;

+(instancetype)environmentForMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user;
-(instancetype)initForMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user;

-(void)start;
-(void)stop;
-(void)updateUser:(LDUserModel*)newUser;

-(BOOL)boolVariation:(NSString *)featureKey fallback:(BOOL)fallback;
-(NSNumber*)numberVariation:(NSString *)featureKey fallback:(NSNumber*)fallback;
-(double)doubleVariation:(NSString *)featureKey fallback:(double)fallback;
-(NSString*)stringVariation:(NSString *)featureKey fallback:(NSString*)fallback;
-(NSArray*)arrayVariation:(NSString *)featureKey fallback:(NSArray*)fallback;
-(NSDictionary*)dictionaryVariation:(NSString *)featureKey fallback:(NSDictionary*)fallback;

-(BOOL)track:(NSString*)eventName data:(NSDictionary *)dataDictionary;
-(BOOL)flush;

@end

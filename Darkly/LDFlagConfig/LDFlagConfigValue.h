//
//  LDFlagConfigValue.h
//  Darkly
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSInteger const kLDFlagConfigVersionDoesNotExist;

@interface LDFlagConfigValue: NSObject
@property (nonatomic, strong) id _Nullable value;
@property (nonatomic, assign) NSInteger version;

+(nullable instancetype)flagConfigValueWithObject:(nullable id)object;
-(nullable instancetype)initWithObject:(nullable id)object;

-(void)encodeWithCoder:(nonnull NSCoder*)encoder;
-(nullable id)initWithCoder:(nonnull NSCoder*)decoder;
-(nonnull NSDictionary*)dictionaryValue;

-(BOOL)isEqual:(nullable id)object;
@end

//
//  LDFlagValueCounter.h
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDFlagValueCounter : NSObject
@property (nonatomic, strong, readonly) id _Nullable value;
@property (nonatomic, assign, readonly) NSInteger variation;
@property (nonatomic, assign, readonly) NSInteger version;
@property (nonatomic, assign, readonly, getter=isUnknown) BOOL unknown;
@property (nonatomic, assign) NSInteger count;

+(instancetype _Nonnull)counterWithValue:(id _Nullable)value variation:(NSInteger)variation version:(NSInteger)version;
-(instancetype _Nonnull)initWithValue:(id _Nullable)value variation:(NSInteger)variation version:(NSInteger)version;
+(instancetype _Nonnull)counterForUnknownValue;
-(instancetype _Nonnull)initForUnknownValue;

-(NSDictionary* _Nonnull)dictionaryValue;

@end

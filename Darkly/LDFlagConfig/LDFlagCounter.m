//
//  LDFlagCounter.m
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagCounter.h"

@interface LDFlagCounter()
@property (nonatomic, strong) NSString *flagKey;
@end

@implementation LDFlagCounter
+(instancetype)counterWithFlagKey:(NSString*)flagKey value:(id)value version:(NSInteger)version variation:(NSInteger)variation defaultValue:(id)defaultValue {
    return [[LDFlagCounter alloc] initWithFlagKey:flagKey value:value version:version variation:variation defaultValue:defaultValue];
}

-(instancetype)initWithFlagKey:(NSString*)flagKey value:(id)value version:(NSInteger)version variation:(NSInteger)variation defaultValue:(id)defaultValue {
    if (!(self = [super init])) { return nil; }

    return self;
}

+(instancetype)counterForUnknownFlagKey:(NSString*)flagKey defaultValue:(id)defaultValue {
    return [[LDFlagCounter alloc] initForUnknownFlagKey:flagKey defaultValue:defaultValue];
}

-(instancetype)initForUnknownFlagKey:(NSString*)flagKey defaultValue:(id)defaultValue {
    if (!(self = [super init])) { return nil; }

    return self;
}

-(void)logRequestWithValue:(id)value version:(NSInteger)version variation:(NSInteger)variation defaultValue:(id)defaultValue {

}

-(NSDictionary*)dictionaryValue {
    return @{};
}

@end

//
//  LDFlagValueCounter.m
//  Darkly
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDFlagValueCounter.h"

@interface LDFlagValueCounter()
@property (nonatomic, strong) id value;
@property (nonatomic, assign) NSInteger variation;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, assign, getter=isUnknown) BOOL unknown;
@end

@implementation LDFlagValueCounter
+(instancetype )counterWithValue:(id _Nullable)value variation:(NSInteger)variation version:(NSInteger)version {
    return [[LDFlagValueCounter alloc] initWithValue:value variation:variation version:version];
}

-(instancetype _Nonnull)initWithValue:(id _Nullable)value variation:(NSInteger)variation version:(NSInteger)version {
    if (!(self = [super init])) { return nil; }

    self.value = value;
    self.variation = variation;
    self.version = version;
    self.unknown = NO;
    self.count = 0;
    
    return self;
}

+(instancetype _Nonnull)counterForUnknownValue {
    return [[LDFlagValueCounter alloc] initForUnknownValue];
}

-(instancetype _Nonnull)initForUnknownValue {
    if (!(self = [super init])) { return nil; }

    return self;
}

-(NSDictionary* _Nonnull)dictionaryValue {
    return @{};
}

@end

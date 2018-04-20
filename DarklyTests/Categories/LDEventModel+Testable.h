//
//  LDEventModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>

@class LDUserModel;
@class LDConfig;

extern NSString * _Nonnull const kEventModelKindFeature;
extern NSString * _Nonnull const kEventModelKindCustom;
extern NSString * _Nonnull const kEventModelKindIdentify;
extern NSString * _Nonnull const kEventModelKindFeatureSummary;

extern NSString * _Nonnull const kFeatureEventKeyStub;
extern NSString * _Nonnull const kCustomEventKeyStub;
extern NSString * _Nonnull const kCustomEventCustomDataKeyStub;
extern NSString * _Nonnull const kCustomEventCustomDataValueStub;
extern const double featureEventValueStub;
extern const double featureEventDefaultValueStub;

@interface LDEventModel(Testable)
@property (nonatomic, assign, readonly) BOOL isFlagRequestEventKind;
@property (nonatomic, assign, readonly) BOOL hasCommonFields;
@property (nonatomic, assign, readonly) BOOL alwaysInlinesUser;
+(nonnull NSArray<NSString*>*)allEventKinds;
+(nonnull NSArray<NSString*>*)eventKindsWithCommonFields;
+(nonnull NSArray<NSString*>*)eventKindsForFlagRequests;
+(nonnull NSArray<NSString*>*)eventKindsThatAlwaysInlineUsers;
+(nonnull instancetype)stubEventWithKind:(nonnull NSString*)eventKind user:(nullable LDUserModel*)user config:(nullable LDConfig*)config;
-(BOOL)isEqual:(nullable id)object;
-(BOOL)hasPropertiesMatchingDictionary:(nullable NSDictionary*)dictionary;
@end

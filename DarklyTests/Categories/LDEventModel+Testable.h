//
//  LDEventModel+Testable.h
//  DarklyTests
//
//  Created by Mark Pokorny on 4/13/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Darkly/Darkly.h>
#import "LDEventModel.h"
#import "NSDate+ReferencedDate.h"

@class LDUserModel;
@class LDConfig;

extern NSString * _Nonnull const kEventModelKindFeature;
extern NSString * _Nonnull const kEventModelKindCustom;
extern NSString * _Nonnull const kEventModelKindIdentify;
extern NSString * _Nonnull const kEventModelKindFeatureSummary;
extern NSString * _Nonnull const kEventModelKindDebug;

extern NSString * _Nonnull const kEventModelKeyKey;
extern NSString * _Nonnull const kEventModelKeyKind;
extern NSString * _Nonnull const kEventModelKeyCreationDate;
extern NSString * _Nonnull const kEventModelKeyData;
extern NSString * _Nonnull const kEventModelKeyFlagConfigValue;
extern NSString * _Nonnull const kEventModelKeyValue;
extern NSString * _Nonnull const kEventModelKeyVersion;
extern NSString * _Nonnull const kEventModelKeyVariation;
extern NSString * _Nonnull const kEventModelKeyIsDefault;
extern NSString * _Nonnull const kEventModelKeyDefault;
extern NSString * _Nonnull const kEventModelKeyUser;
extern NSString * _Nonnull const kEventModelKeyUserKey;
extern NSString * _Nonnull const kEventModelKeyInlineUser;
extern NSString * _Nonnull const kEventModelKeyStartDate;
extern NSString * _Nonnull const kEventModelKeyEndDate;
extern NSString * _Nonnull const kEventModelKeyFeatures;

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
+(nonnull NSArray<NSDictionary*>*)stubEventDictionariesForUser:(nullable LDUserModel*)user config:(nullable LDConfig*)config;
-(BOOL)isEqual:(nullable id)object;
-(BOOL)hasPropertiesMatchingFlagKey:(nonnull NSString*)flagKey
                          eventKind:(nonnull NSString*)eventKind
                    flagConfigValue:(nullable LDFlagConfigValue*)flagConfigValue
                   defaultFlagValue:(nullable id)defaultFlagValue
                               user:(nonnull LDUserModel*)user
                         inlineUser:(BOOL)inlineUser
                 creationDateMillis:(LDMillisecond)creationDateMillis;
@end

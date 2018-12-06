//
//  LDFlagConfigModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagConfigValue;

@interface LDFlagConfigModel : NSObject <NSCoding>

@property (nullable, nonatomic, strong) NSDictionary<NSString*, LDFlagConfigValue*> *featuresJsonDictionary;
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString*, id> *allFlagValues;

-(nullable id)initWithDictionary:(nullable NSDictionary*)dictionary;
-(nullable NSDictionary*)dictionaryValue;
-(nullable NSDictionary*)dictionaryValueIncludeNulls:(BOOL)includeNulls;

-(BOOL)containsFlagKey:(nonnull NSString*)flagKey;
-(nullable LDFlagConfigValue*)flagConfigValueForFlagKey:(nonnull NSString*)flagKey;
-(nullable id)flagValueForFlagKey:(nonnull NSString*)flagKey;
-(NSInteger)flagModelVersionForFlagKey:(nonnull NSString*)flagKey;

-(void)addOrReplaceFromDictionary:(nullable NSDictionary*)eventDictionary;
-(void)deleteFromDictionary:(nullable NSDictionary*)eventDictionary;

-(BOOL)isEqualToConfig:(nullable LDFlagConfigModel*)otherConfig;
-(NSArray<NSString*>*)differingFlagKeysFromConfig:(nullable LDFlagConfigModel*)otherConfig;
-(BOOL)hasFeaturesEqualToDictionary:(nullable NSDictionary*)otherDictionary;

-(void)updateEventTrackingContextFromConfig:(nullable LDFlagConfigModel*)otherConfig;

-(LDFlagConfigModel*)copy;
-(nonnull NSString*)description;
@end

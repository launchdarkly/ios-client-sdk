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

-(nullable id)initWithDictionary:(nullable NSDictionary*)dictionary;
-(nullable NSDictionary*)dictionaryValue;
-(nullable NSDictionary*)dictionaryValueIncludeNulls:(BOOL)includeNulls;

-(BOOL)doesFlagConfigValueExistForFlagKey:(nonnull NSString*)flagKey;
-(nullable LDFlagConfigValue*)flagConfigValueForFlagKey:(nonnull NSString*)flagKey;
-(nullable id)flagValueForFlagKey:(nonnull NSString*)flagKey;
-(NSInteger)flagModelVersionForFlagKey:(nonnull NSString*)flagKey;

-(void)addOrReplaceFromDictionary:(nullable NSDictionary*)patch;
-(void)deleteFromDictionary:(nullable NSDictionary*)delete;

-(BOOL)isEqualToConfig:(nullable LDFlagConfigModel*)otherConfig;
-(BOOL)hasFeaturesEqualToDictionary:(nullable NSDictionary*)otherDictionary;

-(void)updateEventTrackingContextFromConfig:(nullable LDFlagConfigModel*)otherConfig;

-(nonnull NSString*)description;
@end

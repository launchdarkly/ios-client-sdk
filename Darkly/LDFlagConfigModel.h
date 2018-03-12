//
//  LDFlagConfigModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LDFlagConfigValue.h"

@interface LDFlagConfigModel : NSObject <NSCoding>

@property (nullable, nonatomic, strong) NSDictionary<NSString*, LDFlagConfigValue*> *featuresJsonDictionary;

-(nullable id)initWithDictionary:(nullable NSDictionary*)dictionary;
-(nullable NSDictionary*)dictionaryValue;
-(nullable NSDictionary*)dictionaryValueIncludeNulls:(BOOL)includeNulls;

-(BOOL)doesConfigFlagExist:(nonnull NSString*)keyName;
-(nullable id)configFlagValue:(nonnull NSString*)keyName;
-(NSInteger)configFlagVersion:(nonnull NSString*)keyName;

-(void)addOrReplaceFromDictionary:(nullable NSDictionary*)patch;
-(void)deleteFromDictionary:(nullable NSDictionary*)delete;

-(BOOL)isEqualToConfig:(nullable LDFlagConfigModel*)otherConfig;
-(BOOL)hasFeaturesEqualToDictionary:(nullable NSDictionary*)otherDictionary;
@end

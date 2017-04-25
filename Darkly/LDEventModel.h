//
//  LDEventModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDUserModel;

@interface LDEventModel : NSObject <NSCoding>
@property (nullable, nonatomic, strong) NSString *key;
@property (nullable, nonatomic, strong) NSString *kind;
@property (atomic, assign) NSInteger creationDate;
@property (nullable, nonatomic, strong) NSDictionary *data;
@property (nullable, nonatomic, strong) LDUserModel *user;

@property (nonnull, nonatomic, strong) NSObject *value;
@property (nonnull, nonatomic, strong) NSObject *isDefault;

-(nonnull id)initWithDictionary:(nonnull NSDictionary *)dictionary;
-(nonnull NSDictionary *)dictionaryValue;

-(nonnull instancetype)initFeatureEventWithKey:(nonnull NSString *)featureKey keyValue:(NSObject * _Nullable)keyValue defaultKeyValue:(NSObject * _Nullable)defaultKeyValue userValue:(nonnull LDUserModel *)userValue;
-(nonnull instancetype)initCustomEventWithKey: (nonnull NSString *)featureKey
                         andDataDictionary: (nonnull NSDictionary *)customData userValue:(nonnull LDUserModel *)userValue;
@end

//
//  LDUserModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagConfigModel;

@interface LDUserModel : NSObject <NSCoding>
@property (nullable, nonatomic, strong, setter=key:) NSString *key;
@property (nullable, nonatomic, strong) NSString *ip;
@property (nullable, nonatomic, strong) NSString *country;
@property (nullable, nonatomic, strong) NSString *firstName;
@property (nullable, nonatomic, strong) NSString *lastName;
@property (nullable, nonatomic, strong) NSString *email;
@property (nullable, nonatomic, strong) NSString *avatar;
@property (nullable, nonatomic, strong) NSDictionary *custom;
@property (nullable, nonatomic, strong) NSDate *updatedAt;
@property (nullable, nonatomic, strong) LDFlagConfigModel *config;

@property (nonatomic, assign) BOOL anonymous;
@property (nullable, nonatomic, strong) NSString *device;
@property (nullable, nonatomic, strong) NSString *os;

-(nonnull id)initWithDictionary:(nonnull NSDictionary *)dictionary;
-(nonnull NSString *) convertToJson;
-(nonnull NSDictionary *)dictionaryValue;

-(NSObject * __nonnull) flagValue: ( NSString * __nonnull )keyName;
-(BOOL) doesFlagExist: (nonnull NSString *)keyName;

@end

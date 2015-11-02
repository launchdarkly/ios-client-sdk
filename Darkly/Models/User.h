//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>
#import "Config.h"

@interface User : MTLModel <MTLJSONSerializing, MTLManagedObjectSerializing>
@property (nullable, nonatomic, strong, setter=key:) NSString *key;
@property (nullable, nonatomic, strong) NSString *ip;
@property (nullable, nonatomic, strong) NSString *country;
@property (nullable, nonatomic, strong) NSString *firstName;
@property (nullable, nonatomic, strong) NSString *lastName;
@property (nullable, nonatomic, strong) NSString *email;
@property (nullable, nonatomic, strong) NSString *avatar;
@property (nullable, nonatomic, strong) NSDictionary *custom;
@property (nullable, nonatomic, strong) NSDate *updatedAt;
@property (nullable, nonatomic, strong) Config *config;

@property (nonatomic, assign) BOOL anonymous;
@property (nullable, nonatomic, strong) NSString *device;
@property (nullable, nonatomic, strong) NSString *os;

-(BOOL) isFlagOn: (nonnull NSString * )keyName;
-(BOOL) doesFlagExist: (nonnull NSString *)keyName;

@end

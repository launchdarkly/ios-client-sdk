//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>

@class LDUser;

@interface LDFlagConfig : MTLModel<MTLJSONSerializing, MTLManagedObjectSerializing>
@property (nullable, nonatomic, strong) NSDictionary *featuresJsonDictionary;
@property (nullable, nonatomic, strong) NSArray *features;
@property (nullable, nonatomic, strong) LDUser *user;
@property (nullable, nonatomic, strong) NSString *userKey;

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName;
-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName;
@end

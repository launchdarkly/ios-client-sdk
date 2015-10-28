//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Mantle/Mantle.h>
#import <MTLManagedObjectAdapter/MTLManagedObjectAdapter.h>

@interface Event : MTLModel <MTLJSONSerializing, MTLManagedObjectSerializing>
@property (nullable, nonatomic, strong) NSString *key;
@property (nullable, nonatomic, strong) NSString *kind;
@property (nonatomic) NSInteger creationDate;
@property (nullable, nonatomic, strong) NSDictionary *data;

@property (nonatomic, assign) BOOL featureKeyValue;
@property (nonatomic, assign) BOOL isDefault;

-(nonnull instancetype)featureEventWithKey:(nonnull NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue;
-(nonnull instancetype) customEventWithKey: (nonnull NSString *)featureKey
                 andDataDictionary: (nonnull NSDictionary *)customData;
@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDEvent.h"

@implementation LDEvent

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    // mapping between json returned from API and mantle attributes goes here
    return @{@"key": @"key",
             @"kind": @"kind",
             @"creationDate": @"creationDate",
             @"featureKeyValue": @"value",
             @"isDefault": @"default"
             };
}

+ (NSDictionary *)managedObjectKeysByPropertyKey {
    // mapping between    and Mantle object goes here
    return @{@"key": @"key",
             @"kind": @"kind",
             @"creationDate": @"creationDate",
             @"featureKeyValue": @"featureKeyValue",
             @"isDefault": @"isDefault",
             @"data": @"data"
             };
}

+ (NSString *)managedObjectEntityName {
    return @"EventEntity";
}

-(instancetype)featureEventWithKey:(nonnull NSString *)featureKey keyValue:(BOOL)keyValue defaultKeyValue:(BOOL)defaultKeyValue {
    self.key = featureKey;
    self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    self.kind = @"feature";
    self.featureKeyValue = keyValue;
    self.isDefault = defaultKeyValue;
    
    return self;
}

-(instancetype) customEventWithKey: (NSString *)featureKey
                           andDataDictionary: (NSDictionary *)customData  {
    self.key = featureKey;
    self.creationDate = [@(floor([[NSDate date] timeIntervalSince1970]*1000)) longValue];
    self.kind = @"custom";
    self.data = customData;
    
    return self;
}
@end

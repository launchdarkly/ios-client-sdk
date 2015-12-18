//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDFlagConfig.h"
#import "LDFeatureFlag.h"
#import "LDUser.h"
#import "LDUtil.h"

@implementation LDFlagConfig
@synthesize user;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    // mapping between json returned from API and mantle attributes goes here
    return @{@"featuresJsonDictionary": @"items"};
}

+ (NSString *)managedObjectEntityName {
    return @"ConfigEntity";
}

+ (NSDictionary *)managedObjectKeysByPropertyKey {
    // mapping between NSManagaedObject and Mantle object goes here
    return @{@"featuresJsonDictionary": @"featuresJsonDictionary",
             @"user": @"user",
             @"userKey": @"userKey"};
}

+ (NSDictionary *)relationshipModelClassesByPropertyKey {
    return @{
             @"user" : [LDUser class]
             };
}

-(NSArray *)features {
    NSMutableArray *featuresArray = [[NSMutableArray alloc] init];
    
    for(id key in self.featuresJsonDictionary) {
        NSDictionary *featureJson = [self.featuresJsonDictionary objectForKey:key];
        LDFeatureFlag *feature = [[LDFeatureFlag alloc] init];
        feature.key = key;
        
        id aValue = [featureJson valueForKey:@"value"];
        
        if (![aValue isKindOfClass:[NSNull class]] && ![aValue isKindOfClass:[NSString class]]) {
            @try {
                feature.isOn = [aValue boolValue];
                [featuresArray addObject: feature];
            }
            @catch (NSException *exception) {
                DEBUG_LOG(@"Error parsing value for key: %@", feature.key);
            }
        }
    };
    
    return featuresArray;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;
    
    self.featuresJsonDictionary = [dictionaryValue objectForKey:@"featuresJsonDictionary"];
    return self;
}

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName {
    LDFeatureFlag *matchedFeature = nil;
    
    for(LDFeatureFlag *feature in self.features) {
        if([feature.key isEqualToString: keyName])
            matchedFeature = feature;
    };
    
    if(!matchedFeature)
        return false;
        
    return matchedFeature.isOn;
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    LDFeatureFlag *matchedFeature = nil;
    
    for(LDFeatureFlag *feature in self.features) {
        if([feature.key isEqualToString: keyName])
            matchedFeature = feature;
    };
    
    return matchedFeature != nil;
}

-(void)setUser:(LDUser *)aUser {
    user = aUser;
    self.userKey = user.key;
}

+ (NSSet *)propertyKeysForManagedObjectUniquing {
    return [NSSet setWithObject:@"userKey"];
}

@end

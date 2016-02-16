//
//  LDFlagConfigModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDUtil.h"
#import "LDFeatureFlagModel.h"
#import <BlocksKit/BlocksKit.h>

static NSString * const kFeaturesJsonDictionaryKey = @"featuresJsonDictionary";

static NSString * const kFeaturesJsonDictionaryServerKey = @"items";

static NSString * const kFeatureJsonValueName = @"value";

@implementation LDFlagConfigModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.featuresJsonDictionary forKey:kFeaturesJsonDictionaryKey];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.featuresJsonDictionary = [decoder decodeObjectForKey:kFeaturesJsonDictionaryKey];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if((self = [super init])) {
        //Process json that comes down from server
        NSDictionary *featureJsonDictionary = [dictionary objectForKey:kFeaturesJsonDictionaryServerKey];
        if (featureJsonDictionary) {
            NSMutableDictionary *featureFlagDictionary = [[NSMutableDictionary alloc] init];
            for (NSString *key in featureJsonDictionary) {
                NSDictionary *featureFlagTempDictionary = [featureJsonDictionary objectForKey:key];
                [featureFlagDictionary setObject:[[LDFeatureFlagModel alloc] initWithDictionary:featureFlagTempDictionary] forKey:key];
            }
            self.featuresJsonDictionary = featureFlagDictionary;
        }
    }
    return self;
}

-(NSDictionary *)dictionaryValue{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    self.featuresJsonDictionary ? [dictionary setObject:self.featuresJsonDictionary forKey: kFeaturesJsonDictionaryKey] : nil;
    
    return dictionary;
}

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName {
    __block BOOL result = NO;
    
    [self.featuresJsonDictionary bk_each:^(id key, NSDictionary *featureJson) {
        if ([key isEqualToString: keyName]) {
            id aValue = [featureJson valueForKey:kFeatureJsonValueName];
            if (![aValue isKindOfClass:[NSNull class]] && ![aValue isKindOfClass:[NSString class]]) {
                @try {
                    result = [aValue boolValue];
                }
                @catch (NSException *exception) {
                    DEBUG_LOG(@"Error parsing value for key: %@", keyName);
                }
            }
        }
    }];
    return result;
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    return [self.featuresJsonDictionary bk_any:^(id key, NSDictionary *featureJson) {
        return [key isEqualToString: keyName];
    }];
}

@end

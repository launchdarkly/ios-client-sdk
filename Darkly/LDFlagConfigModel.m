//
//  LDFlagConfigModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDUtil.h"

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
        self.featuresJsonDictionary = dictionary;
    }
    return self;
}

-(NSDictionary *)dictionaryValue{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    
    self.featuresJsonDictionary ? [dictionary setObject:self.featuresJsonDictionary forKey: kFeaturesJsonDictionaryKey] : nil;
    
    return dictionary;
}

-(NSObject*) flagValue: ( NSString * __nonnull )keyName {
    NSObject *result = nil;
    
    NSDictionary *featureValue = [self.featuresJsonDictionary objectForKey: keyName];
    
    if (featureValue) {
        id aValue = featureValue;
        if (![aValue isKindOfClass:[NSNull class]]) {
            @try {
                result = aValue;
            }
            @catch (NSException *exception) {
                DEBUG_LOG(@"Error parsing value for key: %@", keyName);
            }
        }
    }
    return result;
}

-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName {
    return [[self.featuresJsonDictionary allKeys] containsObject: keyName];
}

@end

//
//  LDFlagConfigModel.m
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDFeatureFlag.h"
#import "LDUtil.h"
#import <BlocksKit/BlocksKit.h>

@implementation LDFlagConfigModel

- (void)encodeWithCoder:(NSCoder *)encoder {
    //Encode properties, other class variables, etc
    [encoder encodeObject:self.featuresJsonDictionary forKey:@"featuresJsonDictionary"];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if((self = [super init])) {
        //Decode properties, other class vars
        self.featuresJsonDictionary = [decoder decodeObjectForKey:@"featuresJsonDictionary"];
    }
    return self;
}

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName {
    __block BOOL result = NO;
    
    [self.featuresJsonDictionary bk_each:^(id key, NSDictionary *featureJson) {
        LDFeatureFlag *feature = [[LDFeatureFlag alloc] init];
        feature.key = key;
        id aValue = [featureJson valueForKey:@"value"];
        if (![aValue isKindOfClass:[NSNull class]] && ![aValue isKindOfClass:[NSString class]]) {
            @try {
                result = [aValue boolValue];
            }
            @catch (NSException *exception) {
                DEBUG_LOG(@"Error parsing value for key: %@", feature.key);
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

//
//  LDFlagConfigModel+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "NSJSONSerialization+Testable.h"

extern NSString * _Nonnull  const kLDFlagConfigJsonDictionaryKeyVersion;

@implementation LDFlagConfigModel(Testable)
+(instancetype)flagConfigFromJsonFileNamed:(NSString *)fileName {
    return [[LDFlagConfigModel alloc] initWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
}

+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version {
    NSMutableDictionary *patch = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
    patch[kLDFlagConfigJsonDictionaryKeyVersion] = @(version);
    return patch;
}

+(NSDictionary*)patchFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key {
    NSMutableDictionary *patch = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization jsonObjectFromFileNamed:fileName]];
    patch[key] = nil;
    return patch;
}

+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName useVersion:(NSInteger)version {
    return [LDFlagConfigModel patchFromJsonFileNamed:fileName useVersion:version];
}

+(NSDictionary*)deleteFromJsonFileNamed:(NSString *)fileName omitKey:(NSString*)key {
    return [LDFlagConfigModel patchFromJsonFileNamed:fileName omitKey:key];
}
@end

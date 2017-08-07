//
//  LDUserModel+JsonDecodeable.m
//  Darkly
//
//  Created by Mark Pokorny on 7/27/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

#import "LDUserModel+JsonDecodeable.h"

@implementation LDUserModel (JsonDecodeable)
+(LDUserModel*)userFrom:(NSString*)jsonUser {
    NSError *jsonError;
    NSData *userData = [jsonUser dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *userDictionary = [NSJSONSerialization JSONObjectWithData:userData options:0 error:&jsonError];
    return [[LDUserModel alloc] initWithDictionary:userDictionary];
}
@end

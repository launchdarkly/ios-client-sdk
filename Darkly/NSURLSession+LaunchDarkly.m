//
//  NSURLSession+LaunchDarkly.m
//  Darkly
//
//  Created by Mark Pokorny on 11/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSURLSession+LaunchDarkly.h"
#import "DarklyConstants.h"
#import "LDConfig.h"
#import "LDURLCache.h"

@implementation NSURLSession (LaunchDarkly)
static NSURLSession *sharedNSURLSession = nil;

+(NSURLSession*)sharedLDSession {
    return sharedNSURLSession;
}

+(void)setSharedLDSessionForConfig:(LDConfig*)config {
    if (sharedNSURLSession != nil && [sharedNSURLSession sessionMatchesConfig:config]) {
        return;
    }
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLCache *nsUrlCache = [[NSURLCache alloc] initWithMemoryCapacity:kNSURLCacheMemoryCapacity diskCapacity:kNSURLCacheDiskCapacity diskPath:nil];
    sessionConfig.URLCache = [LDURLCache urlCacheForConfig:config usingCache:nsUrlCache];
    sharedNSURLSession = [NSURLSession sessionWithConfiguration:sessionConfig];
}

-(BOOL)sessionMatchesConfig:(LDConfig*)config {
    return ([LDURLCache shouldUseLDURLCacheForConfig:config] && self.hasLDURLCache) || (![LDURLCache shouldUseLDURLCacheForConfig:config] && !self.hasLDURLCache);
}

-(BOOL)hasLDURLCache {
    return [self.configuration.URLCache isKindOfClass:[LDURLCache class]];
}

@end

//
//  LDURLCache.m
//  Darkly
//
//  Created by Mark Pokorny on 11/16/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDURLCache.h"
#import "DarklyConstants.h"
#import "LDUtil.h"
#import "LDConfig.h"

extern NSString * const kFeatureFlagGetUrl;

@interface LDURLCache ()
@property (nonatomic, strong) NSURLCache *baseUrlCache;
@end

@implementation LDURLCache
+(instancetype)urlCacheWithNSURLCache:(NSURLCache*)baseUrlCache {
    return [[LDURLCache alloc] initWithNSURLCache:baseUrlCache];
}

-(instancetype)initWithNSURLCache:(NSURLCache*)baseUrlCache {
    if (baseUrlCache == nil || !(self = [super init])) {
        return nil;
    }
    self.baseUrlCache = baseUrlCache;
    return self;
}

+(NSURLCache*)urlCacheForConfig:(LDConfig*)config usingCache:(NSURLCache*)baseCache {
    if (![LDURLCache shouldUseLDURLCacheForConfig:config]) {
        return baseCache;
    }
    return [LDURLCache urlCacheWithNSURLCache:baseCache];
}

+(BOOL)shouldUseLDURLCacheForConfig:(LDConfig*)config {
    return !config.streaming && config.useReport;
}

-(void)storeCachedResponse:(NSCachedURLResponse*)cachedResponse forDataTask:(NSURLSessionDataTask*)dataTask {
    if (![dataTask.originalRequest.HTTPMethod isEqualToString:kHTTPMethodReport]) {
        [self.baseUrlCache storeCachedResponse:cachedResponse forDataTask:dataTask];
    }
    [self storeCachedResponse:cachedResponse forRequest:dataTask.originalRequest];
}

-(void)storeCachedResponse:(NSCachedURLResponse*)cachedResponse forRequest:(NSURLRequest*)request {
    [self.baseUrlCache storeCachedResponse:cachedResponse forRequest:[self getRequestFromRequest:request]];
}

-(NSURLRequest*)getRequestFromRequest:(NSURLRequest*)request {
    if (![request.HTTPMethod isEqualToString:kHTTPMethodReport]) {
        return request;
    }
    NSString *encodedUser = [LDUtil base64UrlEncodeString:[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@%@", request.URL.scheme, request.URL.host, kFeatureFlagGetUrl, encodedUser]];
    NSMutableURLRequest *getRequest = [NSMutableURLRequest requestWithURL:url];
    getRequest.timeoutInterval = request.timeoutInterval;
    getRequest.cachePolicy = request.cachePolicy;
    getRequest.allHTTPHeaderFields = request.allHTTPHeaderFields;

    return getRequest;
}

-(void)getCachedResponseForDataTask:(NSURLSessionDataTask*)dataTask completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    if (![dataTask.originalRequest.HTTPMethod isEqualToString:kHTTPMethodReport]) {
        [self.baseUrlCache getCachedResponseForDataTask:dataTask completionHandler:completionHandler];
        return;
    }

    NSCachedURLResponse *cachedResponse = [self cachedResponseForRequest:[self getRequestFromRequest:dataTask.originalRequest]];
    if (completionHandler != nil) {
        completionHandler(cachedResponse);
    }
}

-(NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest*)request {
    return [self.baseUrlCache cachedResponseForRequest:[self getRequestFromRequest:request]];
}
@end

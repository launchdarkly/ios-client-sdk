//
//  LDURLCache.h
//  Darkly
//
//  Created by Mark Pokorny on 11/16/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDConfig;

NS_ASSUME_NONNULL_BEGIN

@interface LDURLCache : NSURLCache
+(NSURLCache*)urlCacheForConfig:(LDConfig*)config usingCache:(NSURLCache*)baseCache;

+(BOOL)shouldUseLDURLCacheForConfig:(LDConfig*)config;

-(void)storeCachedResponse:(NSCachedURLResponse*)cachedResponse forDataTask:(NSURLSessionDataTask*)dataTask;
-(void)storeCachedResponse:(NSCachedURLResponse*)cachedResponse forRequest:(NSURLRequest*)request;

-(void)getCachedResponseForDataTask:(NSURLSessionDataTask*)dataTask completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler;
-(NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest*)request;
@end

NS_ASSUME_NONNULL_END

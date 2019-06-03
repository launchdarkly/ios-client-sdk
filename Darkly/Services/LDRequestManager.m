//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDRequestManager.h"
#import "LDUtil.h"
#import "NSURLResponse+LaunchDarkly.h"
#import "NSDictionary+LaunchDarkly.h"
#import "NSHTTPURLResponse+LaunchDarkly.h"
#import "NSURLSession+LaunchDarkly.h"

NSString * const kFeatureFlagGetUrl = @"/msdk/evalx/users/";
static NSString * const kFeatureFlagReportUrl = @"/msdk/evalx/user";
static NSString * const kEventUrl = @"/mobile/events/bulk";
static NSString * const kConfigRequestCompletedNotification = @"config_request_completed_notification";
static NSString * const kEventRequestCompletedNotification = @"event_request_completed_notification";

NSString * const kFlagRequestHeaderIfNoneMatch = @"if-none-match";
NSString * const kEventHeaderLaunchDarklyEventSchema = @"X-LaunchDarkly-Event-Schema";
NSString * const kEventSchema = @"3";

@interface LDRequestManager()
@property (nonnull, nonatomic, copy) NSString* mobileKey;
@property (nonnull, nonatomic) LDConfig *config;
@property (nullable, nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonnull, readonly) dispatch_queue_t responseCallbackQueue;
@property (nullable, copy, nonatomic) NSString *featureFlagEtag;
@end

@implementation LDRequestManager

+(instancetype)requestManagerForMobileKey:(NSString*)mobileKey config:(LDConfig*)config delegate:(id<RequestManagerDelegate>)delegate callbackQueue:(dispatch_queue_t)callbackQueue {
    return [[LDRequestManager alloc] initForMobileKey:mobileKey config:config delegate:delegate callbackQueue:callbackQueue];
}

-(instancetype)initForMobileKey:(NSString*)mobileKey config:(LDConfig*)config delegate:(id<RequestManagerDelegate>)delegate callbackQueue:(dispatch_queue_t)callbackQueue {
    if (!(self = [super init])) {
        return nil;
    }
    self.mobileKey = mobileKey;
    self.config = config;
    self.delegate = delegate;
    self.callbackQueue = callbackQueue;

    return self;
}

-(dispatch_queue_t)responseCallbackQueue {
    if (self.callbackQueue != nil) {
        return self.callbackQueue;
    }
    return dispatch_get_main_queue();
}

-(void)performFeatureFlagRequest:(LDUserModel *)user isOnline:(BOOL)isOnline {
    if (!isOnline) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server because SDK is offline");
        return;
    }
    if (!self.mobileKey) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no mobileKey");
        return;
    }
    if (!user) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no user");
        return;
    }

    if (self.config.useReport) {
        DEBUG_LOGX(@"RequestManager syncing config to server via REPORT");
        NSURLRequest *flagRequestUsingReportMethod = [self flagRequestUsingReportMethodForUser:user];
        __weak typeof(self) weakSelf = self;
        [self performFlagRequest:flagRequestUsingReportMethod completionHandler:^(NSData * _Nullable originalData, NSURLResponse * _Nullable originalResponse, NSError * _Nullable originalError) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if ([strongSelf shouldTryFlagGetRequestForFlagResponse:originalResponse]) {
                NSURLRequest *flagRequestUsingGetMethod = [self flagRequestUsingGetMethodForUser:user];
                if (flagRequestUsingGetMethod) {
                    DEBUG_LOGX(@"RequestManager syncing config to server via GET");
                    
                    [strongSelf performFlagRequest:flagRequestUsingGetMethod completionHandler:^(NSData * _Nullable retriedData, NSURLResponse * _Nullable retriedResponse, NSError * _Nullable retriedError) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [strongSelf processFlagResponse:retriedResponse data:retriedData error:retriedError];
                    }];
                    return;
                }
            }
            [strongSelf processFlagResponse:originalResponse data:originalData error:originalError];
        }];
    } else {
        DEBUG_LOGX(@"RequestManager syncing config to server via GET");

        NSURLRequest *flagRequestUsingGetMethod = [self flagRequestUsingGetMethodForUser:user];
        __weak typeof(self) weakSelf = self;
        [self performFlagRequest:flagRequestUsingGetMethod completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf processFlagResponse:response data:data error:error];
        }];
    }
}

-(BOOL)shouldTryFlagGetRequestForFlagResponse:(NSURLResponse*)flagResponse {
    if (!flagResponse) { return NO; }
    if (![flagResponse isKindOfClass:[NSHTTPURLResponse class]]) { return NO; }
    NSHTTPURLResponse *httpFlagResponse = (NSHTTPURLResponse*)flagResponse;
    return self.config.useReport && [self.config isFlagRetryStatusCode:httpFlagResponse.statusCode];
}

-(void)processFlagResponse:(NSURLResponse*)response data:(NSData*)data error:(NSError*)error {
    BOOL configProcessed = NO;
    NSDictionary *featureFlags;
    if (!error) {
        NSError *jsonError;
        featureFlags = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        configProcessed = (response.isOk && featureFlags != nil) || response.isNotModified;
    }
    if (response.isOk && featureFlags != nil) {
        self.featureFlagEtag = response.etag;
    } else if (!response.isNotModified) {
        self.featureFlagEtag = nil;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.responseCallbackQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.delegate processedConfig:configProcessed jsonConfigDictionary:featureFlags];
    });
}

-(void)performFlagRequest:(NSURLRequest*)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    if (!request) { return; }
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedLDSession] dataTaskWithRequest:request
                                                                       completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([response isUnauthorizedHTTPResponse]) {
            //Calling postNotification on the task completion handler thread causes the LDRequestManager to hang in some situations. Dispatching the postNotification onto the delegateCallbackQueue avoids that hang.
            dispatch_async(strongSelf.responseCallbackQueue, ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];
            });
        }

        if (completionHandler) {
            completionHandler(data, response, error);
        }
    }];
    
    [dataTask resume];
}

-(void)performEventRequest:(NSArray *)eventDictionaries isOnline:(BOOL)isOnline {
    if (!isOnline) {
        DEBUG_LOGX(@"RequestManager unable to sync events to server because SDK is offline");
        return;
    }
    if (!self.mobileKey) {
        DEBUG_LOGX(@"RequestManager unable to sync events to server since no mobileKey");
        return;
    }

    if (!eventDictionaries || eventDictionaries.count == 0) {
        DEBUG_LOGX(@"RequestManager unable to sync events to server since no events");
        return;
    }

    DEBUG_LOGX(@"RequestManager syncing events to server");
    
    NSString *requestUrl = [self.config.eventsUrl stringByAppendingString:kEventUrl];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    [request setTimeoutInterval:[self.config.connectionTimeout doubleValue]];
    [self addEventRequestHeaders:request];

    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:eventDictionaries options:0 error:&error];

    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:postData];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedLDSession] dataTaskWithRequest:request
                                                                       completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([response isUnauthorizedHTTPResponse]) {
            //Calling postNotification on the task completion handler thread causes the LDRequestManager to hang in some situations. Dispatching the postNotification onto the delegateCallbackQueue avoids that hang.
            dispatch_async(strongSelf.responseCallbackQueue, ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil userInfo:@{kLDNotificationUserInfoKeyMobileKey:self.mobileKey}];
            });
        }

        dispatch_async(strongSelf.responseCallbackQueue, ^{
            BOOL processedEvents = !error;
            [strongSelf.delegate processedEvents:processedEvents jsonEventArray:eventDictionaries responseDate:[response headerDate]];
        });
    }];

    [dataTask resume];
}

#pragma mark - requests
-(NSURLRequest*)flagRequestUsingReportMethodForUser:(LDUserModel*)user {
    if (!user) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no user");
        return nil;
    }
    NSString *userJson = [[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString];
    if (!userJson) {
        DEBUG_LOGX(@"RequestManager could not convert user to json, aborting sync config to server");
        return nil;
    }
    
    NSString *requestUrl = [self.config.baseUrl stringByAppendingString:kFeatureFlagReportUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    request.HTTPMethod = kHTTPMethodReport;
    request.HTTPBody = [userJson dataUsingEncoding:NSUTF8StringEncoding];
    [request setTimeoutInterval:[self.config.connectionTimeout doubleValue]];
    request.cachePolicy = [self flagRequestCachePolicyForEtag:self.featureFlagEtag];
    [self addFeatureRequestHeaders:request];
    
    return request;
}

-(NSURLRequest*)flagRequestUsingGetMethodForUser:(LDUserModel*)user {
    if (!user) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no user");
        return nil;
    }
    NSString *userJson = [[user dictionaryValueWithPrivateAttributesAndFlagConfig:NO] jsonString];
    if (!userJson) {
        DEBUG_LOGX(@"RequestManager could not convert user to json, aborting sync config to server");
        return nil;
    }
    NSString *encodedUser = [LDUtil base64UrlEncodeString:userJson];
    if (!encodedUser) {
        DEBUG_LOGX(@"RequestManager could not base64Url encode user, aborting sync config to server");
        return nil;
    }
    NSString *requestUrl = [self.config.baseUrl stringByAppendingString:kFeatureFlagGetUrl];
    requestUrl = [requestUrl stringByAppendingString:encodedUser];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    [request setTimeoutInterval:[self.config.connectionTimeout doubleValue]];
    request.cachePolicy = [self flagRequestCachePolicyForEtag:self.featureFlagEtag];
    [self addFeatureRequestHeaders:request];
    
    return request;
}

-(NSURLRequestCachePolicy)flagRequestCachePolicyForEtag:(NSString*)etag {
    return etag.length == 0 ? NSURLRequestReloadIgnoringLocalCacheData : NSURLRequestUseProtocolCachePolicy;
}

-(void)addFeatureRequestHeaders:(NSMutableURLRequest *)request {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:self.mobileKey];
    
    [request addValue:authKey forHTTPHeaderField:@"Authorization"];
    [request addValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    if (self.featureFlagEtag.length == 0) {
        return;
    }
    [request addValue: self.featureFlagEtag forHTTPHeaderField:kFlagRequestHeaderIfNoneMatch];
}

-(void)addEventRequestHeaders: (NSMutableURLRequest *)request {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:self.mobileKey];
    
    [request addValue:authKey forHTTPHeaderField:@"Authorization"];
    [request addValue:kEventSchema forHTTPHeaderField:kEventHeaderLaunchDarklyEventSchema];
    [request addValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    [request addValue: @"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
}

@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDRequestManager.h"
#import "LDUtil.h"
#import "LDClientManager.h"
#import "LDConfig.h"
#import "NSURLResponse+LaunchDarkly.h"
#import "NSDictionary+JSON.h"
#import "NSHTTPURLResponse+LaunchDarkly.h"

static NSString * const kFeatureFlagGetUrl = @"/msdk/evalx/users/";
static NSString * const kFeatureFlagReportUrl = @"/msdk/evalx/user";
static NSString * const kEventUrl = @"/mobile/events/bulk";
NSString * const kHeaderMobileKey = @"api_key ";
static NSString * const kConfigRequestCompletedNotification = @"config_request_completed_notification";
static NSString * const kEventRequestCompletedNotification = @"event_request_completed_notification";

NSString * const kEventHeaderLaunchDarklyEventSchema = @"X-LaunchDarkly-Event-Schema";
NSString * const kEventSchema = @"3";

@implementation LDRequestManager

@synthesize mobileKey, baseUrl, eventsUrl, connectionTimeout, delegate;

dispatch_queue_t notificationQueue;

+(LDRequestManager *)sharedInstance {
    static LDRequestManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
        [sharedApiManager setDelegate:[LDClientManager sharedInstance]];
        notificationQueue = dispatch_queue_create("com.launchdarkly.LDRequestManager.NotificationQueue", NULL);
    });
    return sharedApiManager;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)configure:(LDConfig*)config {
    self.mobileKey = config.mobileKey;
    self.baseUrl = config.baseUrl;
    self.eventsUrl = config.eventsUrl;
    self.connectionTimeout = [config.connectionTimeout doubleValue];
}

-(void)performFeatureFlagRequest:(LDUserModel *)user
{
    [self configure:[LDClient sharedInstance].ldConfig];
    if (!mobileKey) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no mobileKey");
        return;
    }
    
    if (!user) {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no user");
        return;
    }

    if (![LDClientManager sharedInstance].isOnline) {
        DEBUG_LOGX(@"RequestManager aborting sync config - client is offline");
        return;
    }
    
    if ([LDClient sharedInstance].ldConfig.useReport) {
        DEBUG_LOGX(@"RequestManager syncing config to server via REPORT");
        NSURLRequest *flagRequestUsingReportMethod = [self flagRequestUsingReportMethodForUser:user];
        [self performFlagRequest:flagRequestUsingReportMethod completionHandler:^(NSData * _Nullable originalData, NSURLResponse * _Nullable originalResponse, NSError * _Nullable originalError) {
            
            if ([self shouldTryFlagGetRequestForFlagResponse:originalResponse]) {
                NSURLRequest *flagRequestUsingGetMethod = [self flagRequestUsingGetMethodForUser:user];
                if (flagRequestUsingGetMethod) {
                    DEBUG_LOGX(@"RequestManager syncing config to server via GET");
                    
                    [self performFlagRequest:flagRequestUsingGetMethod completionHandler:^(NSData * _Nullable retriedData, NSURLResponse * _Nullable retriedResponse, NSError * _Nullable retriedError) {
                        [self processFlagResponseWithData:retriedData error:retriedError];
                    }];
                    return;
                }
            }
            [self processFlagResponseWithData:originalData error:originalError];
        }];
    } else {
        DEBUG_LOGX(@"RequestManager syncing config to server via GET");

        NSURLRequest *flagRequestUsingGetMethod = [self flagRequestUsingGetMethodForUser:user];
        [self performFlagRequest:flagRequestUsingGetMethod completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [self processFlagResponseWithData:data error:error];
        }];
    }
}

-(BOOL)shouldTryFlagGetRequestForFlagResponse:(NSURLResponse*)flagResponse {
    if (!flagResponse) { return NO; }
    if (![flagResponse isKindOfClass:[NSHTTPURLResponse class]]) { return NO; }
    NSHTTPURLResponse *httpFlagResponse = (NSHTTPURLResponse*)flagResponse;
    return [LDClient sharedInstance].ldConfig.useReport && [[LDClient sharedInstance].ldConfig isFlagRetryStatusCode:httpFlagResponse.statusCode];
}

-(void)processFlagResponseWithData:(NSData*)data error:(NSError*)error {
    BOOL configProcessed = NO;
    NSDictionary *featureFlags;
    if (!error) {
        NSError *jsonError;
        featureFlags = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        configProcessed = featureFlags != nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate processedConfig:configProcessed jsonConfigDictionary:featureFlags];
    });
}

-(void)performFlagRequest:(NSURLRequest*)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    if (!request) { return; }
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
    
    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if ([response isUnauthorizedHTTPResponse]) {
            //Calling postNotification on the task completion handler thread causes the LDRequestManager to hang in some situations. Dispatching the postNotification onto the notificationQueue avoids that hang.
            dispatch_async(notificationQueue, ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil];
            });
        }

        if (completionHandler) {
            completionHandler(data, response, error);
        }
    }];
    
    [dataTask resume];
}

-(void)performEventRequest:(NSArray *)eventDictionaries {
    [self configure:[LDClient sharedInstance].ldConfig];
    if (!mobileKey) {
        DEBUG_LOGX(@"RequestManager unable to sync events to server since no mobileKey");
        return;
    }

    if (!eventDictionaries || eventDictionaries.count == 0) {
        DEBUG_LOGX(@"RequestManager unable to sync events to server since no events");
        return;
    }

    if (![LDClientManager sharedInstance].isOnline) {
        DEBUG_LOGX(@"RequestManager aborting sync events - client is offline");
        return;
    }

    DEBUG_LOGX(@"RequestManager syncing events to server");
    
    NSURLSession *defaultSession = [NSURLSession sharedSession];
    NSString *requestUrl = [eventsUrl stringByAppendingString:kEventUrl];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    [request setTimeoutInterval:self.connectionTimeout];
    [self addEventRequestHeaders:request];

    NSError *error;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:eventDictionaries options:0 error:&error];

    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:postData];

    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if ([response isUnauthorizedHTTPResponse]) {
            //Calling postNotification on the task completion handler thread causes the LDRequestManager to hang in some situations. Dispatching the postNotification onto the notificationQueue avoids that hang.
            dispatch_async(notificationQueue, ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kLDClientUnauthorizedNotification object:nil];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL processedEvents = !error;
            [self.delegate processedEvents:processedEvents jsonEventArray:eventDictionaries responseDate:[response headerDate]];
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
    
    NSString *requestUrl = [baseUrl stringByAppendingString:kFeatureFlagReportUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    request.HTTPMethod = kHTTPMethodReport;
    request.HTTPBody = [userJson dataUsingEncoding:NSUTF8StringEncoding];
    [request setTimeoutInterval:self.connectionTimeout];
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
    NSString *requestUrl = [baseUrl stringByAppendingString:kFeatureFlagGetUrl];
    requestUrl = [requestUrl stringByAppendingString:encodedUser];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
    [request setTimeoutInterval:self.connectionTimeout];
    [self addFeatureRequestHeaders:request];
    
    return request;
}

-(void)addFeatureRequestHeaders:(NSMutableURLRequest *)request {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:mobileKey];
    
    [request addValue:authKey forHTTPHeaderField:@"Authorization"];
    [request addValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
}

-(void)addEventRequestHeaders: (NSMutableURLRequest *)request {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:mobileKey];
    
    [request addValue:authKey forHTTPHeaderField:@"Authorization"];
    [request addValue:kEventSchema forHTTPHeaderField:kEventHeaderLaunchDarklyEventSchema];
    [request addValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    [request addValue: @"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
}

@end

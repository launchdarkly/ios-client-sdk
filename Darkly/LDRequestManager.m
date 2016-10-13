//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDRequestManager.h"
#import "AFNetworking.h"
#import "LDUtil.h"
#import "LDClientManager.h"
#import "LDConfig.h"

static NSString * const kFeatureFlagUrl = @"/msdk/eval/users/";
static NSString * const kEventUrl = @"/mobile/events/bulk";
static NSString * const kHeaderMobileKey = @"api_key ";
static NSString * const kConfigRequestCompletedNotification = @"config_request_completed_notification";
static NSString * const kEventRequestCompletedNotification = @"event_request_completed_notification";

@implementation LDRequestManager

@synthesize mobileKey, baseUrl, eventsUrl, connectionTimeout, delegate, configRequestInProgress, eventRequestInProgress;

+(LDRequestManager *)sharedInstance
{
    static LDRequestManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
        [sharedApiManager setDelegate:[LDClientManager sharedInstance]];
        LDClient *client = [LDClient sharedInstance];
        LDConfig *config = client.ldConfig;
        [sharedApiManager setMobileKey:config.mobileKey];
        [sharedApiManager setBaseUrl:config.baseUrl];
        [sharedApiManager setEventsUrl:config.eventsUrl];
        [sharedApiManager setConnectionTimeout:[config.connectionTimeout doubleValue]];
    });
    return sharedApiManager;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)performFeatureFlagRequest:(NSString *)encodedUser
{
    DEBUG_LOGX(@"RequestManager syncing config to server");

    if (!configRequestInProgress) {
        if (mobileKey) {
            if (encodedUser) {
                configRequestInProgress = YES;
                
                AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
                [self addFeatureRequestHeaders:manager];
                
                NSString *requestUrl = [baseUrl stringByAppendingString:kFeatureFlagUrl];
                requestUrl = [requestUrl stringByAppendingString:encodedUser];
                
                [manager GET:requestUrl parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    configRequestInProgress = NO;
                    if (responseObject) {
                        [delegate processedConfig:YES jsonConfigDictionary:responseObject configIntervalMillis:kMinimumPollingIntervalMillis];
                    } else {
                        [delegate processedConfig:NO jsonConfigDictionary:nil configIntervalMillis:kMinimumPollingIntervalMillis];
                    }
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    configRequestInProgress = NO;
                    [delegate processedConfig:NO jsonConfigDictionary:nil configIntervalMillis:kMinimumPollingIntervalMillis];
                }];
            } else {
                DEBUG_LOGX(@"RequestManager unable to sync config to server since no encodedUser");
            }
        } else {
            DEBUG_LOGX(@"RequestManager unable to sync config to server since no mobileKey");
        }
    } else {
        DEBUG_LOGX(@"RequestManager already has a sync config in progress");
    }
}

-(void)performEventRequest:(NSData *)jsonEventArray
{
    DEBUG_LOGX(@"RequestManager syncing events to server");
    
    if (!eventRequestInProgress) {
        if (mobileKey) {
            if (jsonEventArray) {
                eventRequestInProgress = YES;
                
                AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
                [self addEventRequestHeaders:manager];
                
                NSString *requestUrl = [eventsUrl stringByAppendingString:kEventUrl];
                
                [manager POST:requestUrl parameters:jsonEventArray progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    // Call delegate method
                    
                    eventRequestInProgress = NO;
                    LDClient *client = [LDClient sharedInstance];
                    LDConfig *config = client.ldConfig;
                    [delegate processedEvents:YES jsonEventArray:jsonEventArray eventIntervalMillis:[config.flushInterval intValue] * kMillisInSecs];
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    // Call delegate method
                    
                    eventRequestInProgress = NO;
                    [delegate processedEvents:NO jsonEventArray:jsonEventArray eventIntervalMillis:kMinimumPollingIntervalMillis];
                    
                }];
            } else {
                DEBUG_LOGX(@"RequestManager unable to sync events to server since no events");
            }
        } else {
            DEBUG_LOGX(@"RequestManager unable to sync events to server since no mobileKey");
        }
    } else {
        DEBUG_LOGX(@"RequestManager already has a sync events in progress");
    }
}

#pragma mark - requests
-(void)addFeatureRequestHeaders:(AFHTTPSessionManager *)manager {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:mobileKey];
    
    [manager.requestSerializer setValue:authKey forHTTPHeaderField:@"Authorization"];
    [manager.requestSerializer setValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
}

-(void)addEventRequestHeaders: (AFHTTPSessionManager *)manager  {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:mobileKey];
    
    [manager.requestSerializer setValue:authKey forHTTPHeaderField:@"Authorization"];
    [manager.requestSerializer setValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    [manager.requestSerializer setValue: @"application/json" forHTTPHeaderField:@"Content-Type"];
    
}

@end

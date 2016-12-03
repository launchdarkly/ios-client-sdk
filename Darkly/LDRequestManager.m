//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDRequestManager.h"
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

                NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
                NSString *requestUrl = [baseUrl stringByAppendingString:kFeatureFlagUrl];
                
                requestUrl = [requestUrl stringByAppendingString:encodedUser];
                
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
                
                [self addFeatureRequestHeaders:request];
                
                NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        configRequestInProgress = NO;
                        if (!error) {
                            NSError *jsonError;
                            NSMutableDictionary * responseObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
                            if (responseObject) {
                                [delegate processedConfig:YES jsonConfigDictionary:responseObject];
                            } else {
                                [delegate processedConfig:NO jsonConfigDictionary:nil];
                            }
                        }
                        else{
                            [delegate processedConfig:NO jsonConfigDictionary:nil];
                        }
                    });
                    
                }];
                
                [dataTask resume];
                
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

-(void)performEventRequest:(NSArray *)jsonEventArray
{
    DEBUG_LOGX(@"RequestManager syncing events to server");
    
    if (!eventRequestInProgress) {
        if (mobileKey) {
            if (jsonEventArray) {
                eventRequestInProgress = YES;
            
                NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
                NSString *requestUrl = [eventsUrl stringByAppendingString:kEventUrl];
                
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
                [self addEventRequestHeaders:request];
                
                NSError *error;
                NSData *postData = [NSJSONSerialization dataWithJSONObject:jsonEventArray options:0 error:&error];
                
                [request setHTTPMethod:@"POST"];
                [request setHTTPBody:postData];
                
                NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        eventRequestInProgress = NO;
                        if (!error) {
                            LDClient *client = [LDClient sharedInstance];
                            LDConfig *config = client.ldConfig;
                            [delegate processedEvents:YES jsonEventArray:jsonEventArray eventIntervalMillis:[config.flushInterval intValue] * kMillisInSecs];
                        }
                        else{
                            [delegate processedEvents:NO jsonEventArray:jsonEventArray eventIntervalMillis:kMinimumPollingIntervalMillis];
                        }
                    });
                }];
                
                [dataTask resume];
                
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
-(void)addFeatureRequestHeaders:(NSMutableURLRequest *)request{
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:mobileKey];
    
    [request addValue:authKey forHTTPHeaderField:@"Authorization"];
    [request addValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
}

-(void)addEventRequestHeaders: (NSMutableURLRequest *)request  {
    NSString *authKey = [kHeaderMobileKey stringByAppendingString:mobileKey];
    
    [request addValue:authKey forHTTPHeaderField:@"Authorization"];
    [request addValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    [request addValue: @"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
}

@end

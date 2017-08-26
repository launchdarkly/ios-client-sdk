//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDRequestManager.h"
#import "LDUtil.h"
#import "LDClientManager.h"
#import "LDConfig.h"

static NSString * const kFeatureFlagUrl = @"/msdk/eval/users/";
static NSString * const kEventUrl = @"/mobile/events/bulk";
NSString * const kHeaderMobileKey = @"api_key ";
static NSString * const kConfigRequestCompletedNotification = @"config_request_completed_notification";
static NSString * const kEventRequestCompletedNotification = @"event_request_completed_notification";

@implementation LDRequestManager

@synthesize mobileKey, baseUrl, eventsUrl, connectionTimeout, delegate;

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
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    if (mobileKey) {
        if (encodedUser) {
            NSURLSession *defaultSession = [NSURLSession sharedSession];
            NSString *requestUrl = [baseUrl stringByAppendingString:kFeatureFlagUrl];
            
            requestUrl = [requestUrl stringByAppendingString:encodedUser];
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
            [request setTimeoutInterval:self.connectionTimeout];
            
            [self addFeatureRequestHeaders:request];
            
            NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                // This comes in on a background thread, there's no reason to do any additional processing of
                // the data on the main thread -- just the notification of the delegate on the main thread.
                BOOL configProcessed = NO;
                NSDictionary *responseDict = nil;
                if (!error) {
                    NSError *jsonError;
                    NSDictionary * responseObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
                    if (responseObject) {
                        configProcessed = YES;
                        responseDict = responseObject;
                    }
                }
                dispatch_semaphore_signal(semaphore);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate processedConfig:configProcessed jsonConfigDictionary:responseDict];
                });
                
            }];
            
            [dataTask resume];
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
        } else {
            DEBUG_LOGX(@"RequestManager unable to sync config to server since no encodedUser");
        }
    } else {
        DEBUG_LOGX(@"RequestManager unable to sync config to server since no mobileKey");
    }
}

-(void)performEventRequest:(NSArray *)jsonEventArray
{
    DEBUG_LOGX(@"RequestManager syncing events to server");
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    if (mobileKey) {
        if (jsonEventArray) {
            NSURLSession *defaultSession = [NSURLSession sharedSession];
            NSString *requestUrl = [eventsUrl stringByAppendingString:kEventUrl];
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requestUrl]];
            [request setTimeoutInterval:self.connectionTimeout];
            [self addEventRequestHeaders:request];
            
            NSError *error;
            NSData *postData = [NSJSONSerialization dataWithJSONObject:jsonEventArray options:0 error:&error];
            
            [request setHTTPMethod:@"POST"];
            [request setHTTPBody:postData];
            
            NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                dispatch_semaphore_signal(semaphore);
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL processedEvents = !error ? YES : NO;
                    [delegate processedEvents:processedEvents jsonEventArray:jsonEventArray];
                });
            }];
            
            [dataTask resume];
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
        } else {
            DEBUG_LOGX(@"RequestManager unable to sync events to server since no events");
        }
    } else {
        DEBUG_LOGX(@"RequestManager unable to sync events to server since no mobileKey");
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

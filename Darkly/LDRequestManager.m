//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDRequestManager.h"
#import "AFNetworking.h"
#import "LDUtil.h"
#import "LDClientManager.h"
#import "LDConfig.h"

static NSString * const kFeatureFlagUrl = @"/mobile/eval/users/";
static NSString * const kEventUrl = @"/mobile/events/bulk";
static NSString * const kHeaderApiKey = @"api_key ";
static NSString * const kConfigRequestCompletedNotification = @"config_request_completed_notification";
static NSString * const kEventRequestCompletedNotification = @"event_request_completed_notification";

@implementation LDRequestManager

@synthesize apiKey, baseUrl, connectionTimeout, delegate, configRequestInProgress, eventRequestInProgress;

+(LDRequestManager *)sharedInstance
{
    static LDRequestManager *sharedApiManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApiManager = [[self alloc] init];
        [sharedApiManager setDelegate:[LDClientManager sharedInstance]];
        LDClient *client = [LDClient sharedInstance];
        LDConfig *config = client.ldConfig;
        [sharedApiManager setApiKey:config.apiKey];
        [sharedApiManager setBaseUrl:config.baseUrl];
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
        if (apiKey) {
            if (encodedUser) {
                configRequestInProgress = YES;
                NSMutableURLRequest *request = [self featuresWithEncodedUserRequest:encodedUser];
                AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
                op.responseSerializer = [AFJSONResponseSerializer serializer];

                [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                    dispatch_async(dispatch_get_main_queue(),^{
                        configRequestInProgress = NO;
                        if (responseObject && [operation response]) {
                            NSDictionary *headerDictionary = [[operation response] allHeaderFields];
                            int configMaxAge = 0;
                            
                            // need to process the Expires header first because the
                            // max-age directive should override the Expires header, even if
                            // Expires header is more restrictive.

                            if ([headerDictionary valueForKey:@"Expires"] != nil)
                            {
                                // response comes in as Expires: Tue, 15 May 2008 07:19:00 GMT
                                
                                NSString *queryExpiresString =[headerDictionary valueForKey:@"Expires"];
                                
                                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                                [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
                                [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
                                
                                NSDate *endDateTime = [formatter dateFromString:queryExpiresString];
                                
                                NSTimeInterval dateTime = [endDateTime timeIntervalSinceNow];    //Gets difference in seconds
                                if (dateTime >= 0)
                                    configMaxAge = dateTime;
                                
                                // 0 should be minimum for max age.
                                if (configMaxAge < 0)
                                    configMaxAge = 0;
                                
                            }
                            if ([headerDictionary valueForKey:@"Cache-Control"] != nil)
                            {
                                // response comes in as max-age=x seconds...
                                // loop through the string just in case there are extra variables in the cache-control
                                // and max-age doesn't appear first.
                                
                                NSString *queryString =[headerDictionary valueForKey:@"Cache-Control"];
                             
                                NSMutableDictionary *cacheControlQueryStrings = [[NSMutableDictionary alloc] init];
                                for (NSString *qs in [queryString componentsSeparatedByString:@" "]) {
                                    // Get the parameter name
                                    NSString *key = [[qs componentsSeparatedByString:@"="] objectAtIndex:0];
                                    // Get the parameter value
                                    NSString *value = [[qs componentsSeparatedByString:@"="] objectAtIndex:1];
 
                                    cacheControlQueryStrings[key] = value;
                                    
                                    if ([key isEqualToString:@"max-age"])
                                    {
                                        configMaxAge = [value intValue];
                                        break;
                                    }
                                    
                                }
                            }
                            
                            [delegate processedConfig:YES jsonConfigDictionary:responseObject configIntervalMillis:configMaxAge*kMillisInSecs];
                        } else {
                            [delegate processedConfig:NO jsonConfigDictionary:nil configIntervalMillis:kMinimumPollingIntervalMillis];
                        }
                    });
                } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(),^{
                        configRequestInProgress = NO;
                        [delegate processedConfig:NO jsonConfigDictionary:nil configIntervalMillis:kMinimumPollingIntervalMillis];
                    });
                }];
                [op start];
            } else {
                DEBUG_LOGX(@"RequestManager unable to sync config to server since no encodedUser");
            }
        } else {
            DEBUG_LOGX(@"RequestManager unable to sync config to server since no apiKey");
        }
    } else {
        DEBUG_LOGX(@"RequestManager already has a sync config in progress");
    }
}

-(void)performEventRequest:(NSData *)jsonEventArray
{
    DEBUG_LOGX(@"RequestManager syncing events to server");
    
    if (!eventRequestInProgress) {
        if (apiKey) {
            if (jsonEventArray) {
                eventRequestInProgress = YES;
                NSMutableURLRequest *request = [self eventsRequestWithJsonEvents:jsonEventArray];
                AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
                op.responseSerializer = [AFJSONResponseSerializer serializer];

                [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                    // Call delegate method
                    dispatch_async(dispatch_get_main_queue(),^{
                        eventRequestInProgress = NO;
                        LDClient *client = [LDClient sharedInstance];
                        LDConfig *config = client.ldConfig;
                        [delegate processedEvents:YES jsonEventArray:jsonEventArray eventIntervalMillis:[config.flushInterval intValue] * kMillisInSecs];
                    });
                } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    // Call delegate method
                    dispatch_async(dispatch_get_main_queue(),^{
                        eventRequestInProgress = NO;
                        [delegate processedEvents:NO jsonEventArray:jsonEventArray eventIntervalMillis:kMinimumPollingIntervalMillis];
                    });
                }];
                [op start];
            } else {
                DEBUG_LOGX(@"RequestManager unable to sync events to server since no events");
            }
        } else {
            DEBUG_LOGX(@"RequestManager unable to sync events to server since no apiKey");
        }
    } else {
        DEBUG_LOGX(@"RequestManager already has a sync events in progress");
    }
}

#pragma mark - requests
-(NSMutableURLRequest *)featuresWithEncodedUserRequest:(NSString *)encodedUser {
    NSString *requestUrl = [baseUrl stringByAppendingString:kFeatureFlagUrl];
    requestUrl = [requestUrl stringByAppendingString:encodedUser];
    NSURL *URL = [NSURL URLWithString:requestUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:connectionTimeout];
    NSString *authKey = [kHeaderApiKey stringByAppendingString:apiKey];
    [request setValue:authKey forHTTPHeaderField:@"Authorization"];
    [request setValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    [request setHTTPMethod:@"GET"];
    return request;

}

-(NSMutableURLRequest *)eventsRequestWithJsonEvents: (NSData *)jsonEventArray  {
    NSString *requestUrl = [baseUrl stringByAppendingString:kEventUrl];
    NSURL *URL = [NSURL URLWithString:requestUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:connectionTimeout];
    NSString *authKey = [kHeaderApiKey stringByAppendingString:apiKey];
    
    [request setValue:authKey forHTTPHeaderField:@"Authorization"];
    [request setValue:[@"iOS/" stringByAppendingString:kClientVersion] forHTTPHeaderField:@"User-Agent"];
    [request setValue: @"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:jsonEventArray];
    
    return request;
}

@end

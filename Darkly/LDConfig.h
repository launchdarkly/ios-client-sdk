//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDConfig : NSObject {
    
}

@property (nonatomic) NSString* mobileKey;
@property (nonatomic) NSString* baseUrl;
@property (nonatomic) NSString* eventsUrl;
@property (nonatomic) NSNumber* capacity;
@property (nonatomic) NSNumber* connectionTimeout;
@property (nonatomic) NSNumber* flushInterval;
@property (nonatomic) NSNumber* pollingInterval;
@property (nonatomic) BOOL streaming;
@property (nonatomic) BOOL debugEnabled;

@end

@interface LDConfigBuilder : NSObject {
    
}

/**
 * Provide an mobileKey to the configuration builder. This is the mobileKey
 * retrieved from the Launch Darkly account settings. (Required)
 *
 * @param mobileKey    the mobileKey for the configuration
 * @return the configuration builder
 */
- (LDConfigBuilder *)withMobileKey:(NSString *)mobileKey;
/**
 * Provide the baseUrl of the Launch Darkly server. This will allow you
 * to switch between production and staging environments. (Optional)
 *
 * @param baseUrl    the baseUrl of the server
 * @return the configuration builder
 */
- (LDConfigBuilder *)withBaseUrl:(NSString *)baseUrl;
/**
 * Provide the eventsUrl of the Launch Darkly server. This will allow you
 * to switch between production and staging environments. (Optional)
 *
 * @param eventsUrl    the eventsUrl of the server
 * @return the configuration builder
 */
- (LDConfigBuilder *)withEventsUrl:(NSString *)eventsUrl;
/**
 * Provide the capacity for storing feature flag and custom events. Events
 * are persisted on the client and then synced to the server on a regular 
 * basis. If there is ever a prolonged period of time between the last server
 * sync, the capacity defined here will determine at what points the events
 * are ignored and no longer stored. The default is 100. (Optional)
 *
 * @param capacity  the number of events to store
 * @return the configuration builder
 */
- (LDConfigBuilder *)withCapacity:(int)capacity;
/**
 * The connection timeout to be used when syncing to the Launch Darkly 
 * server. The default is 10 seconds. (Optional)
 *
 * @param connectionTimeout timeout for network connections in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withConnectionTimeout:(int)connectionTimeout;
/**
 * The interval at which events are synced to the server. The default
 * is 30 seconds for streaming mode; in polling mode, the flush interval defaults to the polling interval. (Optional)
 *
 * @param flushInterval the flush interval in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withFlushInterval:(int)flushInterval;
/**
 * Set the polling interval (in seconds) for polling mode only. An interval
 * less than 60 is set to the minimum (1 minute). The default is 5 minutes. (Optional)
 *
 * @param pollingInterval the polling interval in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withPollingInterval:(int)pollingInterval;
/**
 * Enable streaming mode for flags. When streaming is false, disable streaming and switch to polling mode. (Optional)
 *
 * @param streamingEnabled Whether streaming is enabled or not
 * @return the configuration builder
 */
- (LDConfigBuilder *)withStreaming:(BOOL)streamingEnabled;
/**
 * Enable debug mode to allow things such as logging. (Optional)
 *
 * @param debugEnabled Whether debugging is enabled or not
 * @return the configuration builder
 */
- (LDConfigBuilder *)withDebugEnabled:(BOOL)debugEnabled;

-(LDConfig *)build;

@end

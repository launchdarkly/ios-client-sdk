//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LDConfig : NSObject

/**
 This is the mobile key retrieved from the LaunchDarkly account settings.
 */
@property (nonatomic, readonly) NSString* mobileKey;

/**
 These are the names and mobile keys for secondary environments to use in the SDK. The
 property must specify a 1:1 mapping of environment name to mobile key. Neither
 kLDPrimaryEnvironmentName nor the value in mobileKey may appear in secondaryMobileKeys.
 Neither the names nor mobile keys may be empty. If any of these conditions are not met
 the SDK will throw an NSInvalidArgumentException. Optional. The default is nil.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString*, NSString*> *secondaryMobileKeys;

/**
 The base URL of the LaunchDarkly service, should you need to override
 the default.
 */
@property (nonatomic, copy, nullable) NSString* baseUrl;

/**
 The events URL of the LaunchDarkly service, should you need to override
 the default.
 */
@property (nonatomic, copy, nullable) NSString* eventsUrl;

/**
 The event source stream URL to the LaunchDarkly event source, should you need to override
 the default.
 */
@property (nonatomic, copy, nullable) NSString* streamUrl;

/**
 The capacity for storing feature flag and custom events. Events
 are persisted on the client and then sent to the server on a regular
 basis. If there is ever a prolonged period of time between the last server
 sync, the capacity defined here will determine at what points the events
 are ignored and no longer stored. The default is 100.
 */
@property (nonatomic, copy, nullable) NSNumber* capacity;

/**
 The connection timeout to be used when syncing to the LaunchDarkly
 server. The default is 10 seconds.
 */
@property (nonatomic, copy, nullable) NSNumber* connectionTimeout;

/**
 The interval at which events are synced to the server. The default
 is 30 seconds for streaming mode; in polling mode, the flush interval defaults
 to the polling interval. (Optional)
 */
@property (nonatomic, copy, nullable) NSNumber* flushInterval;

/**
 The polling interval (in seconds) for polling mode only. An interval
 less than 300 is set to the default (5 minutes).
 */
@property (nonatomic, copy, nullable) NSNumber* pollingInterval;

/**
 * The background fetch interval (in seconds) for background fetch. An interval
 * less than 900 is set to the minimum (15 minutes). The default is 60 minutes. (Optional)
 */
@property (nonatomic, copy, nullable) NSNumber* backgroundFetchInterval;

/**
 Flag that enables streaming mode. When streaming is false, disable streaming
 and switch to polling mode.
 */
@property (nonatomic) BOOL streaming;

/**
 List of user attributes and top level custom dictionary keys to treat as private for event reporting.
 Private attribute values will not be included in events reported to Launch Darkly, but the attribute name will still
 be sent. All user attributes can be declared private except key, anonymous, device, & os. Access the user attribute names
 that can be declared private through the identifiers included in LDUserModel.h. To declare all user attributes private,
 either set privateUserAttributes to [LDUserModel allUserAttributes] or set LDConfig.allUserAttributesPrivate. In either case,
 setting attributes to private in the config causes the LDClient to treat the attribute(s) as private for all users.
 The default is nil.
 */
@property (nonatomic, strong, nullable) NSArray<NSString *>* privateUserAttributes;

/**
 Flag that tells the LDClient to treat all user attributes as private for all users. When set, ignores any values in
 either LDConfig.privateUserAttributes or LDUserModel.privateAttributes. The LDClient will not send any private attributes
 in event reports as described for privateUserAttributes. The default is NO.
 */
@property (nonatomic, assign) BOOL allUserAttributesPrivate;

/**
 Flag that enables REPORT HTTP method for feature flag requests. When useReport is false,
 feature flag requests use the GET HTTP method. The default is NO.
 Do not use unless advised by LaunchDarkly.
 */
@property (nonatomic, assign) BOOL useReport;

/**
 Flag that tells the SDK to include the user attributes in analytics event reports. When set to YES, event reports will
 contain the user attributes, except attributes marked as private. When set to NO, event reports will contain the user's key
 only, reducing the size of event reports. The default is NO.
 */
@property (nonatomic, assign) BOOL inlineUserInEvents;

/**
 Flag that enables debug mode to allow things such as logging.
 */
@property (nonatomic) BOOL debugEnabled;

/**
 Initializes an LDConfig object with the provided mobile key.
 @param mobileKey The mobileKey retrieved from the LaunchDarkly account settings.
 @return An instance of LDConfig object.
 */
- (instancetype)initWithMobileKey:(NSString *)mobileKey NS_DESIGNATED_INITIALIZER;
- (BOOL)isFlagRetryStatusCode:(NSInteger)statusCode;
-(NSString*)secondaryMobileKeysDescription;
- (instancetype)init NS_UNAVAILABLE;

@end

__deprecated_msg("Use LDConfig instead")
@interface LDConfigBuilder : NSObject

@property (nonatomic, strong) LDConfig *config;

- (instancetype)init;

/**
 * Provide an mobileKey to the configuration builder. This is the mobileKey
 * retrieved from the LaunchDarkly account settings. (Required)
 *
 * @param mobileKey    the mobileKey for the configuration
 * @return the configuration builder
 */
- (LDConfigBuilder *)withMobileKey:(NSString *)mobileKey __deprecated_msg("Use `setMobileKey:` on an LDConfig object");
/**
 * Provide the baseUrl of the LaunchDarkly server. This will allow you
 * to switch between production and staging environments. (Optional)
 *
 * @param baseUrl    the baseUrl of the server
 * @return the configuration builder
 */
- (LDConfigBuilder *)withBaseUrl:(NSString *)baseUrl __deprecated_msg("Use `setBaseUrl:` on an LDConfig object");
/**
 * Provide the eventsUrl of the LaunchDarkly server. This will allow you
 * to switch between production and staging environments. (Optional)
 *
 * @param eventsUrl    the eventsUrl of the server
 * @return the configuration builder
 */
- (LDConfigBuilder *)withEventsUrl:(nullable NSString *)eventsUrl __deprecated_msg("Use `setEventsUrl:` on an LDConfig object");
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
- (LDConfigBuilder *)withCapacity:(int)capacity __deprecated_msg("Use `setCapacity:` on an LDConfig object");
/**
 * The connection timeout to be used when syncing to the LaunchDarkly
 * server. The default is 10 seconds. (Optional)
 *
 * @param connectionTimeout timeout for network connections in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withConnectionTimeout:(int)connectionTimeout __deprecated_msg("Use `setConnectionTimeout:` on an LDConfig object");
/**
 * The interval at which events are synced to the server. The default
 * is 30 seconds for streaming mode; in polling mode, the flush interval defaults to the polling interval. (Optional)
 *
 * @param flushInterval the flush interval in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withFlushInterval:(int)flushInterval __deprecated_msg("Use `setFlushInterval:` on an LDConfig object");
/**
 * Set the polling interval (in seconds) for polling mode only. An interval
 * less than 300 is set to the minimum (5 minutes). The default is 5 minutes. (Optional)
 *
 * @param pollingInterval the polling interval in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withPollingInterval:(int)pollingInterval __deprecated_msg("Use `setPollingInterval:` on an LDConfig object");
/**
 * Set the background fetch interval (in seconds) for background fetch. An interval
 * less than 900 is set to the minimum (15 minutes). The default is 60 minutes. (Optional)
 *
 * @param backgroundFetchInterval the background fetch interval in seconds
 * @return the configuration builder
 */
- (LDConfigBuilder *)withBackgroundFetchInterval:(int)backgroundFetchInterval __deprecated_msg("Use `setBackgroundFetchInterval:` on an LDConfig object");
/**
 * Enable streaming mode for flags. When streaming is false, disable streaming and switch to polling mode. (Optional)
 *
 * @param streamingEnabled Whether streaming is enabled or not
 * @return the configuration builder
 */
- (LDConfigBuilder *)withStreaming:(BOOL)streamingEnabled __deprecated_msg("Use `setStreaming:` on an LDConfig object");
/**
 * Enable debug mode to allow things such as logging. (Optional)
 *
 * @param debugEnabled Whether debugging is enabled or not
 * @return the configuration builder
 */
- (LDConfigBuilder *)withDebugEnabled:(BOOL)debugEnabled __deprecated_msg("Use `setDebugEnabled:` on an LDConfig object");

-(LDConfig *)build;

NS_ASSUME_NONNULL_END

@end

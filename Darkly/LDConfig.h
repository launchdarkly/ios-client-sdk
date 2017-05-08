//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDConfig : NSObject

/**
 This is the mobileKey retrieved from the Launch Darkly account settings.
 */
@property (nonatomic, readonly, nonnull) NSString* mobileKey;

/**
 The baseUrl of the Launch Darkly server. This will allow you to
 switch between production and staging environments.
 */
@property (nonatomic, copy, nullable) NSString* baseUrl;

/**
 The eventsUrl of the Launch Darkly server. This will allow you
 to switch between production and staging environments.
 */
@property (nonatomic, copy, nullable) NSString* eventsUrl;

/**
 The capacity for storing feature flag and custom events. Events
 are persisted on the client and then synced to the server on a regular
 basis. If there is ever a prolonged period of time between the last server
 sync, the capacity defined here will determine at what points the events
 are ignored and no longer stored. The default is 100.
 */
@property (nonatomic, copy, nullable) NSNumber* capacity;

/**
 The connection timeout to be used when syncing to the Launch Darkly
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
 Flag that enables streaming mode. When streaming is false, disable streaming
 and switch to polling mode.
 */
@property (nonatomic) BOOL streaming;

/**
 Flat that enables debug mode to allow things such as logging.
 */
@property (nonatomic) BOOL debugEnabled;

/**
 Initializes an LDConfig object with the provided mobile key.
 @param mobileKey The mobileKey retrieved from the Launch Darkly account settings.
 @return An instance of LDConfig object.
 */
- (instancetype _Nonnull)initWithMobileKey:(nonnull NSString *)mobileKey NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull )init NS_UNAVAILABLE;

@end

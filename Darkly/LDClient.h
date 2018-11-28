//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "LDUserBuilder.h"
#import "LDClientInterface.h"

@class LDUserModel;

@protocol ClientDelegate <NSObject>
@optional
-(void)userDidUpdate;
-(void)userUnchanged;
-(void)featureFlagDidUpdate:(NSString *)key;
-(void)serverConnectionUnavailable;
@end

@interface LDClient : NSObject<LDClientInterface>

@property (nonatomic, assign, readonly) BOOL isOnline;
@property (nonatomic, strong, readonly) LDUserModel *ldUser;
@property (nonatomic, strong, readonly) LDConfig *ldConfig;
@property (nonatomic, copy, readonly) NSString *environmentName;
@property (nonatomic, weak) id<ClientDelegate> delegate;
@property (nonatomic, strong, readonly) NSDictionary<NSString*, id> *allFlags;

+ (LDClient *)sharedInstance;

#pragma mark - SDK Control

/**
 * Start the client with a valid configuration and user.
 *
 * @param inputConfigBuilder Desired configuration for the client.
 * @param inputUserBuilder  Desired user for the client.
 * @return whether the client was able to be started.
 */
- (BOOL)start:(LDConfigBuilder *)inputConfigBuilder userBuilder:(LDUserBuilder *)inputUserBuilder __deprecated_msg("Use start:withUserBuilder: instead");

/**
 * Start the client with a valid configuration and user.
 *
 * @param inputConfig Desired configuration for the client.
 * @param inputUserBuilder  Desired user for the client.
 * @return whether the client was able to be started.
 */
- (BOOL)start:(LDConfig *)inputConfig withUserBuilder:(LDUserBuilder *)inputUserBuilder;

/**
 * Set the client to online/offline mode. When online events will be synced to server. (Default)
 *
 * @param goOnline    Desired online/offline mode for the client
 */
- (void)setOnline:(BOOL)goOnline;

/**
 * Set the client to online/offline mode. When online events will be synced to server. (Default)
 *
 * @param goOnline    Desired online/offline mode for the client
 * @param completion    Completion block called when setOnline completes
 */
- (void)setOnline:(BOOL)goOnline completion:(void(^)(void))completion;

/**
 * Sync all events to the server. Events are synced to the server on a
 * regular basis, however this will force all stored events from the client
 * to be synced immediately to the server.
 *
 * @return whether events were able to be flushed.
 */
- (BOOL)flush;

/**
 * Stop the client.
 *
 * @return whether the client was able to be stopped.
 */
- (BOOL)stopClient;

#pragma mark - Variation

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey    Key of feature flag
 * @param fallback  Fallback value for feature flag
 * @return the feature flag value
 */
- (BOOL)boolVariation:(NSString *)featureKey fallback:(BOOL)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (NSNumber*)numberVariation:(NSString *)featureKey fallback:(NSNumber*)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (double)doubleVariation:(NSString *)featureKey fallback:(double)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (NSString*)stringVariation:(NSString *)featureKey fallback:(NSString*)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (NSArray*)arrayVariation:(NSString *)featureKey fallback:(NSArray*)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (NSDictionary*)dictionaryVariation:(NSString *)featureKey fallback:(NSDictionary*)fallback;

#pragma mark - Event

/**
 * Track a custom event.
 *
 * @param eventName Name of the custom event
 * @param dataDictionary  Data to be attached to custom event
 * @return whether the event was successfully recorded
 */
- (BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary;

#pragma mark - User

/**
 * Update the user after the client has started. This will override
 * user information passed in via the start method.
 *
 * @param builder   Desired user for the client
 * @return whether the user was successfully updated
 */
- (BOOL)updateUser:(LDUserBuilder *)builder;

/**
 * Retrieve the current user.
 *
 * @return the current user.
 */
- (LDUserBuilder *)currentUserBuilder;

#pragma mark - Multiple Environments

/**
 * Class method that returns the LDClientInterface object for the environment referenced by the
 * name parameter. The SDK must be started, otherwise the method returns nil even if the name
 * appears in secondaryMobileKeys. If the name doesn't match any of the names (map keys) in
 * secondaryMobileKeys, or the kLDPrimaryEnvironmentName, the method throws an
 * NSIllegalArgumentException.
 *
 * @param name  name associated with a mobile key in secondaryMobileKeys
 *
 * @return  the LDClientInterface object associated with name in secondaryMobileKeys
 */
+(id<LDClientInterface>)environmentForMobileKeyNamed:(NSString*)name;

@end

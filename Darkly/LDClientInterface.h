//
//  LDClientInterface.h
//  Darkly
//
//  Created by Mark Pokorny on 11/1/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ClientDelegate;
@class LDUserBuilder;

NS_ASSUME_NONNULL_BEGIN

@protocol LDClientInterface <NSObject>

@property (nonatomic, copy, readonly) NSString *environmentName;    ///The name associated with the environment in LDConfig.
@property (nonatomic, weak, nullable) id<ClientDelegate> delegate;
@property (nonatomic, strong, readonly, nullable) NSDictionary<NSString*, id> *allFlags;   ///Dictionary of <flagKey: flagValue> for all feature flags in the environment

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
- (nullable NSNumber*)numberVariation:(NSString *)featureKey fallback:(nullable NSNumber*)fallback;

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
- (nullable NSString*)stringVariation:(NSString *)featureKey fallback:(nullable NSString*)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (nullable NSArray*)arrayVariation:(NSString *)featureKey fallback:(nullable NSArray*)fallback;

/**
 * Retrieve a feature flag value. If the configuration for this feature
 * flag is retrieved from the server that value is returned, otherwise
 * the fallback is returned.
 *
 * @param featureKey   Key of feature flag
 * @param fallback   Fallback value for feature flag
 * @return the feature flag value
 */
- (nullable NSDictionary*)dictionaryVariation:(NSString *)featureKey fallback:(nullable NSDictionary*)fallback;

#pragma mark - Event

/**
 * Track a custom event.
 *
 * @param eventName Name of the custom event
 * @param dataDictionary  Data to be attached to custom event
 * @return whether the event was successfully recorded
 */
- (BOOL)track:(NSString *)eventName data:(nullable NSDictionary *)dataDictionary;

NS_ASSUME_NONNULL_END

@end

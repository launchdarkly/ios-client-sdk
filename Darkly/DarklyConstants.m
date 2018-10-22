//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyConstants.h"

NSString * const kClientVersion = @"2.13.8";
NSString * const kBaseUrl = @"https://app.launchdarkly.com";
NSString * const kEventsUrl = @"https://mobile.launchdarkly.com";
NSString * const kStreamUrl = @"https://clientstream.launchdarkly.com";
NSString * const kNoMobileKeyExceptionName = @"NoMobileKeyDefinedException";
NSString * const kNoMobileKeyExceptionReason = @"A valid MobileKey must be provided";
NSString * const kNilConfigExceptionName = @"NilConfigException";
NSString * const kNilConfigExceptionReason = @"A valid LDConfig must be provided";
NSString * const kClientNotStartedExceptionName = @"ClientNotStartedException";
NSString * const kClientNotStartedExceptionReason = @"The LDClient must be started before this method can be called";
NSString * const kClientAlreadyStartedExceptionName = @"ClientAlreadyStartedException";
NSString * const kClientAlreadyStartedExceptionReason = @"The LDClient can only be started once";
NSString * const kIphone = @"iPhone";
NSString * const kIpad = @"iPad";
NSString * const kAppleWatch = @"Apple Watch";
NSString * const kAppleTV = @"Apple TV";
NSString * const kMacOS = @"macOS";
NSString * const kUserDictionaryStorageKey = @"ldUserModelDictionary";
NSString * const kDeviceIdentifierKey = @"ldDeviceIdentifier";
NSString * const kLDUserUpdatedNotification = @"Darkly.UserUpdatedNotification";
NSString * const kLDUserNoChangeNotification = @"Darkly.UserNoChangeNotification";
NSString * const kLDBackgroundFetchInitiated = @"Darkly.BackgroundFetchInitiated";
NSString * const kLDFlagConfigChangedNotification = @"Darkly.FlagConfigChangedNotification";
NSString * const kLDServerConnectionUnavailableNotification = @"Darkly.ServerConnectionUnavailableNotification";
NSString * const kLDClientUnauthorizedNotification = @"Darkly.LDClientUnauthorizedNotification";
NSString * const kHTTPMethodReport = @"REPORT";
int const kCapacity = 100;
int const kConnectionTimeout = 10;
int const kDefaultFlushInterval = 30;
int const kMinimumFlushIntervalMillis = 0;
int const kDefaultPollingInterval = 300;
#if DEBUG
int const kMinimumPollingInterval = 30;
#else
int const kMinimumPollingInterval = 300;
#endif
int const kDefaultBackgroundFetchInterval = 3600;
int const kMinimumBackgroundFetchInterval = 900;
int const kMillisInSecs = 1000;
NSInteger const kHTTPStatusCodeBadRequest = 400;
NSInteger const kHTTPStatusCodeUnauthorized = 401;
NSInteger const kHTTPStatusCodeMethodNotAllowed = 405;
NSInteger const kHTTPStatusCodeNotImplemented = 501;
NSInteger const kErrorCodeUnauthorized = -kHTTPStatusCodeUnauthorized;
NSTimeInterval const kMaxThrottlingDelayInterval = 600.0;

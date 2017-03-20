//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyConstants.h"

NSString * const kClientVersion = @"2.1.2";
NSString * const kBaseUrl = @"https://app.launchdarkly.com";
NSString * const kEventsUrl = @"https://mobile.launchdarkly.com";
NSString * const kStreamUrl = @"https://stream.launchdarkly.com/mping";
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
NSString * const kUserDictionaryStorageKey = @"ldUserModelDictionary";
NSString * const kLDUserUpdatedNotification = @"Darkly.UserUpdatedNotification";
NSString * const kLDBackgroundFetchInitiated = @"Darkly.BackgroundFetchInitiated";
NSString *const kLDFlagConfigChangedNotification = @"Darkly.FlagConfigChangedNotification";
int const kCapacity = 100;
int const kConnectionTimeout = 10;
int const kDefaultFlushInterval = 30;
int const kMinimumPollingIntervalMillis = 0;
int const kMillisInSecs = 1000;

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyConstants.h"

NSString * const kClientVersion = @"0.2.2-beta";
NSString * const kBaseUrl = @"https://app.launchdarkly.com";
NSString * const kNoApiKeyExceptionName = @"NoApiKeyDefinedException";
NSString * const kNoApiKeyExceptionReason = @"A valid ApiKey must be provided";
NSString * const kNilConfigExceptionName = @"NilConfigException";
NSString * const kNilConfigExceptionReason = @"A valid LDConfig must be provided";
NSString * const kClientNotStartedExceptionName = @"ClientNotStartedException";
NSString * const kClientNotStartedExceptionReason = @"The LDClient must be started before this method can be called";
NSString * const kClientAlreadyStartedExceptionName = @"ClientAlreadyStartedException";
NSString * const kClientAlreadyStartedExceptionReason = @"The LDClient can only be started once";
NSString * const kIphone = @"iPhone";
NSString * const kIpad = @"iPad";
int const kCapacity = 100;
int const kConnectionTimeout = 10;
int const kDefaultFlushInterval = 30;
int const kDefaultConfigCheckInterval = 60;
float const kMinimumPollingInterval = 0.0;

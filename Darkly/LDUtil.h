//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDClient.h"
#import "DarklyConstants.h"
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#define CRITICAL_LOGX(string) \
if ([LDUtil logLevel] >= DarklyLogLevelCriticalOnly) { \
NSLog(string); \
}

#define CRITICAL_LOG(format, ...) \
if ([LDUtil logLevel] >= DarklyLogLevelCriticalOnly) { \
NSLog(format, __VA_ARGS__); \
}

#define DEBUG_LOGX(string) \
if ([LDUtil logLevel] >= DarklyLogLevelDebug) { \
NSLog(string); \
}

#define DEBUG_LOG(format, ...) \
if ([LDUtil logLevel] >= DarklyLogLevelDebug) { \
NSLog(format, __VA_ARGS__); \
}

#define PRIVATE_LOGX(string) \
if (DEBUG) { \
NSLog(string); \
}

#define PRIVATE_LOG(format, ...) \
if (DEBUG) { \
NSLog(format, __VA_ARGS__); \
}

#define DARKLY_ASSERT(condition, msg) \
if (!(condition) && DEBUG) { \
[NSException raise:@"Assertion Failure" format:@"%s [Line %d] " msg, __PRETTY_FUNCTION__, __LINE__]; \
}

@interface LDUtil : NSObject
{
    
}

// <--- debug assert ---
+ (void)assertThreadIsNotMain;

// <---- device info ----
+ (NSInteger)getSystemVersionAsAnInteger;
+ (NSString *)getDeviceAsString;
+ (NSString *)getSystemVersionAsString;

// <--- logging ---
+ (void)setLogLevel:(DarklyLogLevel)value;
+ (DarklyLogLevel)logLevel;

+ (NSString *)base64EncodeString:(NSString *)unencodedString;
+ (NSString *)base64DecodeString:(NSString *)encodedString;
+ (NSString *)base64UrlEncodeString:(NSString *)unencodedString;
+ (NSString *)base64UrlDecodeString:(NSString *)encodedString;
+ (void)throwException:(NSString *)name reason:(NSString *)reason;

@end


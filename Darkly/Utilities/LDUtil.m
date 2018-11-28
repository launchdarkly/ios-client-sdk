//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDUtil.h"

#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

@implementation LDUtil


+ (void)assertThreadIsNotMain
{
#ifndef NDEBUG
    if ([LDUtil getSystemVersionAsAnInteger] >= __IPHONE_4_0 &&
        ![[[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIApplicationExitsOnSuspend"] boolValue])
    {
        assert(![NSThread isMainThread]);
    }
#endif
}

+ (NSString *)getDeviceAsString
{
#if TARGET_OS_IOS
    if ([[UIDevice currentDevice] respondsToSelector:@selector(userInterfaceIdiom)]) {
        switch ([[UIDevice currentDevice] userInterfaceIdiom]) {
            case UIUserInterfaceIdiomPhone:
                return kIphone;
            case UIUserInterfaceIdiomPad:
                return kIpad;
            default:
                break;
        }
    }
    return @"";
#elif TARGET_OS_TV
    return kAppleTV;    //UIUserInterfaceIdiomTV is available from iOS 9, and so TODO: When iOS 8 is no longer supported, refactor to use UIUserInterfaceIdiomTV in the switch above
#elif TARGET_OS_WATCH
    return kAppleWatch;
#elif TARGET_OS_OSX
    return kMacOS;
#endif
    return @"";
}

+ (NSString *)getSystemVersionAsString
{
#if TARGET_OS_IOS || TARGET_OS_TV
    return [[UIDevice currentDevice] systemVersion];
#elif TARGET_OS_WATCH
    return [[WKInterfaceDevice currentDevice] systemVersion];
#elif TARGET_OS_OSX
    return [[NSProcessInfo processInfo] operatingSystemVersionString];
#endif
    return @"";
}

+ (NSInteger)getSystemVersionAsAnInteger {
    int index = 0;
    static NSInteger version = 0;
    
    @synchronized (self) {
        if(version != 0) {
            // PRIVATE_LOG(@"Darkly: System version found already. [%d]", version);
            return version;
        }
        
        NSArray* digits = [[self getSystemVersionAsString] componentsSeparatedByString:@"."];
        NSEnumerator* enumer = [digits objectEnumerator];
        NSString* number;
        while (number = [enumer nextObject]) {
            if (index>2) {
                break;
            }
            NSInteger multipler = powf(100, 2-index);
            version += [number intValue]*multipler;
            index++;
        }
        
        // PRIVATE_LOG(@"Darkly: System version [%d]", version);
    }
    return version;
}

static DarklyLogLevel gLogLevel = DarklyLogLevelCriticalOnly;


+ (void)setLogLevel:(DarklyLogLevel)value
{
    DEBUG_LOG(@"DarklyUtil LogLevel set to: %u", value);
    gLogLevel = value;
}

+ (DarklyLogLevel)logLevel
{
    return gLogLevel;
}

+ (NSString *)base64EncodeString:(NSString *)unencodedString
{
    DEBUG_LOG(@"DarklyUtil base64EncodeString method called on string: %@", unencodedString);
    NSData *plainData = [unencodedString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [plainData base64EncodedStringWithOptions:0];
    return base64String;
}

+ (NSString *)base64DecodeString:(NSString *)encodedString
{
    DEBUG_LOG(@"DarklyUtil base64DecodeString method called on string: %@", encodedString);
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedString options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    return decodedString;
}

+ (NSString *)base64UrlEncodeString:(NSString *)unencodedString
{
    DEBUG_LOG(@"DarklyUtil base64UrlEncodeString method called on string: %@\nDarklyUtil will call base64EncodeString next", unencodedString);
    return [[[LDUtil base64EncodeString:unencodedString] stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
}

+ (NSString *)base64UrlDecodeString:(NSString *)encodedString
{
    DEBUG_LOG(@"DarklyUtil base64UrlDecodeString method called on string: %@\nDarklyUtil will call base64DecodeString next", encodedString);
    return [LDUtil base64DecodeString: [[encodedString stringByReplacingOccurrencesOfString:@"_" withString:@"/"] stringByReplacingOccurrencesOfString:@"-" withString:@"+"]];
}

+ (void)throwException:(NSString *)name reason:(NSString *)reason
{
    NSException *e = [NSException
                      exceptionWithName:name
                      reason:reason
                      userInfo:nil];
    @throw e;
}


@end

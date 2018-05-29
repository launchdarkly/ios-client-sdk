//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDRequestManager.h"
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#if TARGET_OS_WATCH
@interface LDClientManager : NSObject  <RequestManagerDelegate> {
}
#elif TARGET_OS_OSX
@interface LDClientManager : NSObject  <RequestManagerDelegate, NSApplicationDelegate> {
}
#else
@interface LDClientManager : NSObject  <RequestManagerDelegate> {
}
#endif

@property (nonatomic, assign, getter=isOnline) BOOL online;

+(LDClientManager *)sharedInstance;

- (void)syncWithServerForEvents;
- (void)syncWithServerForConfig;
- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray*)jsonEventArray responseDate:(NSDate*)responseDate;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary;
- (void)startPolling;
- (void)stopPolling;
- (void)updateUser;
- (void)willEnterBackground;
- (void)willEnterForeground;
- (void)flushEvents;

@end

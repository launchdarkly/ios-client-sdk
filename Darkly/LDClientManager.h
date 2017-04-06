//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//



#import "LDRequestManager.h"
#import <DarklyEventSource/EventSource.h>

#if TARGET_OS_OSX
    #import <AppKit/AppKit.h>

    @interface LDClientManager : NSObject  <RequestManagerDelegate, NSApplicationDelegate> {}
#else
    #import <UIKit/UIKit.h>

    @interface LDClientManager : NSObject  <RequestManagerDelegate, UIApplicationDelegate> {}
#endif


@property (nonatomic) BOOL offlineEnabled;
@property(nonatomic, strong, readonly) EventSource *eventSource;

+(LDClientManager *)sharedInstance;

- (void)syncWithServerForEvents;
- (void)syncWithServerForConfig;
- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary;
- (void)startPolling;
- (void)stopPolling;
- (void)willEnterBackground;
- (void)willEnterForeground;
- (void)flushEvents;

@end

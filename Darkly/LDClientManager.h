//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDRequestManager.h"
#import <UIKit/UIKit.h>
#import <DarklyEventSource/EventSource.h>

extern NSString *const kLDUserUpdatedNotification;
extern NSString *const kLDBackgroundFetchInitiated;

@interface LDClientManager : NSObject  <RequestManagerDelegate, UIApplicationDelegate> {
}

@property (nonatomic) BOOL offlineEnabled;
@property(nonatomic, strong, readonly) EventSource *eventSource;

+(LDClientManager *)sharedInstance;

- (void)syncWithServerForEvents;
- (void)syncWithServerForConfig;
- (void)processedEvents:(BOOL)success jsonEventArray:(NSData *)jsonEventArray eventIntervalMillis:(int)eventIntervalMillis;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary configIntervalMillis:(int)configIntervalMillis;
- (void)startPolling;
- (void)stopPolling;
- (void)willEnterBackground;
- (void)willEnterForeground;
- (void)flushEvents;

@end

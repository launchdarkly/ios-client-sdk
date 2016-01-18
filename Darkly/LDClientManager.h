//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDRequestManager.h"

extern NSString *const kLDUserUpdatedNotification;

@interface LDClientManager : NSObject  <RequestManagerDelegate> {
}

@property (nonatomic) BOOL offlineEnabled;

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

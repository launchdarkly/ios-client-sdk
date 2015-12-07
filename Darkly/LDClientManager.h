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
- (void)processedEvents:(BOOL)success jsonEventArray:(NSData *)jsonEventArray eventInterval:(int)eventInterval;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary configInterval:(int)configInterval;
- (void)startPolling;
- (void)stopPolling;
- (void)flushEvents;

@end

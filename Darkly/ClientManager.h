//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "RequestManager.h"

extern NSString *const kLDUserUpdatedNotification;

@interface ClientManager : NSObject  <RequestManagerDelegate> {
}

@property (nonatomic) BOOL offlineEnabled;

+(ClientManager *)sharedInstance;

- (void)syncWithServerForEvents;
- (void)syncWithServerForConfig;
- (void)processedEvents:(BOOL)success jsonEventArray:(NSData *)jsonEventArray eventInterval:(int)eventInterval;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary configInterval:(int)configInterval;
- (void)startPolling;
- (void)stopPolling;
- (void)flushEvents;

@end

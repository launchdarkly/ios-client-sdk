//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "Config.h"

@protocol RequestManagerDelegate <NSObject>

- (void)processedEvents:(BOOL)success jsonEventArray:(NSData *)jsonEventArray eventInterval:(int)eventInterval;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary configInterval:(int)configInterval;

@end

@interface RequestManager : NSObject {
    
}

@property (nonatomic) NSString* apiKey;
@property (nonatomic) NSString* baseUrl;
@property (nonatomic) NSTimeInterval connectionTimeout;
@property (nonatomic, weak) id <RequestManagerDelegate> delegate;
@property (nonatomic, assign) BOOL configRequestInProgress;
@property (nonatomic, assign) BOOL eventRequestInProgress;

+(RequestManager *)sharedInstance;

-(void)performFeatureFlagRequest:(NSString *)encodedUser;

-(void)performEventRequest:(NSData *)jsonEventArray;

@end

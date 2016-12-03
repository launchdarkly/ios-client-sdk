//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDFlagConfigModel.h"

@protocol RequestManagerDelegate <NSObject>

- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray eventIntervalMillis:(int)eventIntervalMillis;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary;

@end

@interface LDRequestManager : NSObject {
    
}

@property (nonatomic) NSString* mobileKey;
@property (nonatomic) NSString* baseUrl;
@property (nonatomic) NSString* eventsUrl;
@property (nonatomic) NSTimeInterval connectionTimeout;
@property (nonatomic, weak) id <RequestManagerDelegate> delegate;
@property (nonatomic, assign) BOOL configRequestInProgress;
@property (nonatomic, assign) BOOL eventRequestInProgress;

+(LDRequestManager *)sharedInstance;

-(void)performFeatureFlagRequest:(NSString *)encodedUser;

-(void)performEventRequest:(NSArray *)jsonEventArray;

@end

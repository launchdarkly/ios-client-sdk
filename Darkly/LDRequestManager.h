//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDUserModel.h"

@protocol RequestManagerDelegate <NSObject>

- (void)processedEvents:(BOOL)success jsonEventArray:(NSArray *)jsonEventArray;
- (void)processedConfig:(BOOL)success jsonConfigDictionary:(NSDictionary *)jsonConfigDictionary;

@end

@interface LDRequestManager : NSObject

extern NSString * const kHeaderMobileKey;
@property (nonatomic) NSString* mobileKey;
@property (nonatomic) NSString* baseUrl;
@property (nonatomic) NSString* eventsUrl;
@property (nonatomic) NSTimeInterval connectionTimeout;
@property (nonatomic, weak) id <RequestManagerDelegate> delegate;

+(LDRequestManager *)sharedInstance;

-(void)performFeatureFlagRequest:(LDUserModel *)user;

-(void)performEventRequest:(NSArray *)eventDictionaries;

@end

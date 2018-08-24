//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDUserModel.h"

@protocol RequestManagerDelegate <NSObject>

-(void)processedEvents:(BOOL)success jsonEventArray:(nonnull NSArray*)jsonEventArray responseDate:(nullable NSDate*)responseDate;
-(void)processedConfig:(BOOL)success jsonConfigDictionary:(nonnull NSDictionary*)jsonConfigDictionary;

@end

extern NSString * _Nonnull const kHeaderMobileKey;

@interface LDRequestManager : NSObject

@property (nonnull, nonatomic, copy) NSString* mobileKey;
@property (nonnull, nonatomic, copy) NSString* baseUrl;
@property (nonnull, nonatomic, copy) NSString* eventsUrl;
@property (nonatomic, assign) NSTimeInterval connectionTimeout;
@property (nullable, nonatomic, weak) id <RequestManagerDelegate> delegate;

+(nonnull LDRequestManager*)sharedInstance;

-(void)performFeatureFlagRequest:(nullable LDUserModel*)user;

-(void)performEventRequest:(nullable NSArray*)eventDictionaries;

@end

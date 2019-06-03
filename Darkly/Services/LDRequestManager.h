//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDUserModel.h"
#import "LDConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol RequestManagerDelegate <NSObject>
-(void)processedEvents:(BOOL)success jsonEventArray:(NSArray*)jsonEventArray responseDate:(nullable NSDate*)responseDate;
-(void)processedConfig:(BOOL)success jsonConfigDictionary:(nullable NSDictionary*)jsonConfigDictionary;
@end

@interface LDRequestManager : NSObject
@property (nonatomic, copy, readonly) NSString* mobileKey;
@property (nullable, nonatomic, weak) id<RequestManagerDelegate> delegate;

+(nullable instancetype)requestManagerForMobileKey:(NSString*)mobileKey
                                            config:(LDConfig*)config
                                          delegate:(nullable id<RequestManagerDelegate>)delegate
                                     callbackQueue:(nullable dispatch_queue_t)callbackQueue;
-(nullable instancetype)initForMobileKey:(NSString*)mobileKey
                                  config:(LDConfig*)config
                                delegate:(nullable id<RequestManagerDelegate>)delegate
                           callbackQueue:(nullable dispatch_queue_t)callbackQueue;

-(void)performFeatureFlagRequest:(nullable LDUserModel*)user isOnline:(BOOL)isOnline;
-(void)performEventRequest:(nullable NSArray*)eventDictionaries isOnline:(BOOL)isOnline;
@end

NS_ASSUME_NONNULL_END

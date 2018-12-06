//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


#import "LDRequestManager.h"
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif
#import "LDConfig.h"
#import "LDUserModel.h"

@class LDDataManager;

#if TARGET_OS_OSX
@interface LDEnvironmentController : NSObject  <RequestManagerDelegate, NSApplicationDelegate> {
}
#else
@interface LDEnvironmentController : NSObject  <RequestManagerDelegate> {
}
#endif

NS_ASSUME_NONNULL_BEGIN

@property (nonatomic, assign, getter=isOnline) BOOL online;
@property (nonatomic, copy, readonly) NSString *mobileKey;
@property (nonatomic, strong, readonly) LDConfig *config;
@property (nonatomic, strong, readonly) LDUserModel *user;

+(instancetype)controllerWithMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user dataManager:(LDDataManager*)dataManager;
-(instancetype)initWithMobileKey:(NSString*)mobileKey config:(LDConfig*)config user:(LDUserModel*)user dataManager:(LDDataManager*)dataManager;

-(void)flushEvents;

NS_ASSUME_NONNULL_END

@end

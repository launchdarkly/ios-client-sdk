
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#import "LDClient.h"

@interface RNLaunchDarkly : RCTEventEmitter <RCTBridgeModule>

@property(nonatomic) LDUserModel *user;

@end


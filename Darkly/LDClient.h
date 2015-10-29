//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "LDConfig.h"
#import "LDUserBuilder.h"

@class LDConfig;
@class LDUserBuilder;


@protocol ClientDelegate
@property (nonatomic, weak) id<ClientDelegate> delegate;
-(void)userDidUpdate;
@end

@interface LDClient : NSObject

@property(nonatomic, strong, readonly) User *user;
@property(nonatomic, strong, readonly) LDConfig *ldConfig;
@property (nonatomic, assign) id delegate;

+ (id)sharedInstance;

- (BOOL)start:(LDConfigBuilder *)inputConfigBuilder userBuilder:(LDUserBuilder *)inputUserBuilder;
- (BOOL)toggle:(NSString *)featureName default:(BOOL)defaultValue;
- (BOOL)track:(NSString *)eventName data:(NSDictionary *)dataDictionary;
- (BOOL)updateUser:(LDUserBuilder *)builder;
- (LDUserBuilder *)currentUserBuilder;
- (BOOL)offline;
- (BOOL)online;
- (BOOL)flush;
- (BOOL)stopClient;

@end

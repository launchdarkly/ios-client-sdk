//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//


@class User;

@interface FeatureFlag : NSObject 
@property (nullable, nonatomic, strong) NSString *key;
@property (nonatomic, assign) BOOL isOn;

@end

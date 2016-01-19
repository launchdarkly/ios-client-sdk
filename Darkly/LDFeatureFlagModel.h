//
//  LDFeatureFlagModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDFeatureFlagModel : NSObject <NSCoding>
@property (nullable, nonatomic, strong) NSString *key;
@property (nonatomic, assign) BOOL isOn;

- (nonnull id)initWithDictionary:(nonnull NSDictionary *)dictionary;

@end

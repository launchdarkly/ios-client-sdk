//
//  LDEventTrackingContext.h
//  Darkly
//
//  Created by Mark Pokorny on 5/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDEventTrackingContext : NSObject<NSCoding, NSCopying>
@property (nonatomic, assign) BOOL trackEvents;
@property (nullable, nonatomic, strong) NSDate *debugEventsUntilDate;

+(nullable instancetype)contextWithObject:(nullable id)object;
-(nullable instancetype)initWithObject:(nullable id)object;
-(nonnull NSDictionary*)dictionaryValue;
-(void)encodeWithCoder:(nonnull NSCoder*)aCoder;
-(nullable instancetype)initWithCoder:(nonnull NSCoder*)aDecoder;
-(nonnull NSString*)description;
-(id)copyWithZone:(nullable NSZone*)zone;
@end

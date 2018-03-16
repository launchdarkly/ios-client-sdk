//
//  LDEvent+EventTypes.h
//  Darkly
//
//  Created by Mark Pokorny on 2/5/18.
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <DarklyEventSource/LDEventSource.h>

extern NSString * const kLDEventTypePing;
extern NSString * const kLDEventTypePut;
extern NSString * const kLDEventTypePatch;
extern NSString * const kLDEventTypeDelete;

@interface LDEvent (EventTypes)

@end

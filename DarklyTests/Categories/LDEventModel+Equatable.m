//
//  LDEventModel+Equatable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/11/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventModel+Equatable.h"
#import "LDUserModel+Equatable.h"

extern NSString * const kEventModelKindFeature;
extern NSString * const kEventModelKindCustom;
extern NSString * const kEventModelKindIdentify;

extern NSString * const kEventModelKeyKey;
extern NSString * const kEventModelKeyKind;
extern NSString * const kEventModelKeyCreationDate;
extern NSString * const kEventModelKeyData;
extern NSString * const kEventModelKeyValue;
extern NSString * const kEventModelKeyIsDefault;
extern NSString * const kEventModelKeyDefault;
extern NSString * const kEventModelKeyUser;
extern NSString * const kEventModelKeyUserKey;
extern NSString * const kEventModelKeyInlineUser;

@implementation LDEventModel(Equatable)
-(BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[LDEventModel class]]) {
        NSLog(@"[%@ %@]: object is not class %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), NSStringFromClass([self class]));
        return NO;
    }
    LDEventModel *otherEvent = object;

    NSMutableArray<NSString*> *mismatchedFields = [NSMutableArray array];
    if (![self.key isEqualToString:otherEvent.key]) {
        [mismatchedFields addObject:kEventModelKeyKey];
    }
    if (![self.kind isEqualToString:otherEvent.kind]) {
        [mismatchedFields addObject:kEventModelKeyKind];
    }
    if (self.inlineUser != otherEvent.inlineUser) {
        [mismatchedFields addObject:kEventModelKeyInlineUser];
    }
    if (self.inlineUser) {
        if (![self.user isEqual:otherEvent.user ignoringAttributes:@[kUserAttributeConfig]]) {
            [mismatchedFields addObject:kEventModelKeyUser];
        }
    } else {
        if (![self.user.key isEqualToString:otherEvent.user.key]) {
            [mismatchedFields addObject:kEventModelKeyUserKey];
        }
    }
    if (self.creationDate != otherEvent.creationDate) {
        [mismatchedFields addObject:kEventModelKeyCreationDate];
    }

    if ([self.kind isEqualToString:kEventModelKindFeature]) {
        if (![self.value isEqual:otherEvent.value]) {
            [mismatchedFields addObject:kEventModelKeyValue];
        }
        if (![self.defaultValue isEqual:otherEvent.defaultValue]) {
            [mismatchedFields addObject:kEventModelKeyDefault];
        }
    }

    if ([self.kind isEqualToString:kEventModelKindCustom]) {
        if (![self.data isEqual:otherEvent.data]) {
            [mismatchedFields addObject:kEventModelKeyData];
        }
    }

    //identify events have only the fields common to all events

    if (mismatchedFields.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedFields componentsJoinedByString:@", "]);
        return NO;
    }
    
    return YES;
}

-(BOOL)hasPropertiesMatchingDictionary:(NSDictionary*)dictionary {
    NSMutableArray<NSString*> *mismatchedFields = [NSMutableArray array];
    if (![self.key isEqualToString:dictionary[kEventModelKeyKey]]) {
        [mismatchedFields addObject:kEventModelKeyKey];
    }
    if (![self.kind isEqualToString:dictionary[kEventModelKeyKind]]) {
        [mismatchedFields addObject:kEventModelKeyKind];
    }
    if (self.inlineUser) {
        if (![self.user.key isEqualToString:dictionary[kEventModelKeyUser][kUserAttributeKey]]) {
            [mismatchedFields addObject:kEventModelKeyUser];
        }
    } else {
        if (![self.user.key isEqualToString:dictionary[kEventModelKeyUserKey]]) {
            [mismatchedFields addObject:kEventModelKeyUserKey];
        }
    }
    //If the event and dictionary have creation dates within 1 millisecond, that's close enough...
    if (labs(self.creationDate - [dictionary[kEventModelKeyCreationDate] integerValue]) > 1) {
        [mismatchedFields addObject:kEventModelKeyCreationDate];
    }

    if ([self.kind isEqualToString:kEventModelKindFeature]) {
        if (![self.value isEqual:dictionary[kEventModelKeyValue]]) {
            [mismatchedFields addObject:kEventModelKeyValue];
        }
        if (![self.defaultValue isEqual:dictionary[kEventModelKeyDefault]]) {
            [mismatchedFields addObject:kEventModelKeyDefault];
        }
    }

    if ([self.kind isEqualToString:kEventModelKindCustom]) {
        if (![self.data isEqual:dictionary[kEventModelKeyData]]) {
            [mismatchedFields addObject:kEventModelKeyData];
        }
    }

    //identify events have only the fields common to all events
    if (mismatchedFields.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedFields componentsJoinedByString:@", "]);
        return NO;
    }

    return YES;
}
@end

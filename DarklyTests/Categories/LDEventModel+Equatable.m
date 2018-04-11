//
//  LDEventModel+Equatable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/11/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDEventModel+Equatable.h"
#import "LDUserModel+Equatable.h"

extern NSString * const kEventNameFeature;
extern NSString * const kEventNameCustom;
extern NSString * const kEventNameIdentify;

extern NSString * const kKeyKey;
extern NSString * const kKeyKind;
extern NSString * const kKeyCreationDate;
extern NSString * const kKeyData;
extern NSString * const kKeyValue;
extern NSString * const kKeyIsDefault;
extern NSString * const kKeyDefault;
extern NSString * const kKeyUser;
extern NSString * const kKeyInlineUser;

@implementation LDEventModel(Equatable)
-(BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[LDEventModel class]]) {
        NSLog(@"[%@ %@]: object is not class %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), NSStringFromClass([self class]));
        return NO;
    }
    LDEventModel *otherEvent = object;

    NSMutableArray<NSString*> *mismatchedFields = [NSMutableArray array];
    if (![self.key isEqualToString:otherEvent.key]) { [mismatchedFields addObject:kKeyKey]; }
    if (![self.kind isEqualToString:otherEvent.kind]) { [mismatchedFields addObject:kKeyKind]; }
    if (![self.user isEqual:otherEvent.user ignoringAttributes:@[@"config"]]) { [mismatchedFields addObject:kKeyUser]; }
    if (self.inlineUser != otherEvent.inlineUser) { [mismatchedFields addObject:kKeyInlineUser]; }
    if (self.creationDate != otherEvent.creationDate) { [mismatchedFields addObject:kKeyCreationDate]; }

    if ([self.kind isEqualToString:kEventNameFeature]) {
        if (![self.value isEqual:otherEvent.value]) { [mismatchedFields addObject:kKeyValue]; }
        if (![self.defaultValue isEqual:otherEvent.defaultValue]) { [mismatchedFields addObject:kKeyDefault]; }
    }

    if ([self.kind isEqualToString:kEventNameCustom]) {
        if (![self.data isEqual:otherEvent.data]) { [mismatchedFields addObject:kKeyData]; }
    }

    //identify events have only the fields common to all events

    if (mismatchedFields.count > 0) {
        NSLog(@"[%@ %@] unequal fields %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [mismatchedFields componentsJoinedByString:@", "]);
        return NO;
    }
    
    return YES;
}
@end

//
//  LDConfig+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 10/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "LDConfig+Testable.h"

NSString * const LDConfigTestEnvironmentNameMock = @"Name";
NSString * const LDConfigTestSecondaryMobileKeyMock = @"Key";

@interface LDConfig (Testable_Private)
@property (nonatomic, strong, readonly, class) NSArray<NSString*> *environmentSuffixes;
@end

@implementation LDConfig (Testable)
@dynamic flagRetryStatusCodes;

+(NSArray<NSString*>*)environmentSuffixes {
    return @[@"A", @"B", @"C", @"D", @"E"];
}

+(NSDictionary<NSString*,NSString*>*)secondaryMobileKeysStub {
    NSMutableDictionary *secondaryMobileKeys = [NSMutableDictionary dictionaryWithCapacity:self.environmentSuffixes.count];
    for (NSString *suffix in self.environmentSuffixes) {
        secondaryMobileKeys[[NSString stringWithFormat:@"%@.%@", LDConfigTestEnvironmentNameMock, suffix]] =
            [NSString stringWithFormat:@"%@.%@", LDConfigTestSecondaryMobileKeyMock, suffix];
    }
    return [secondaryMobileKeys copy];
}
@end

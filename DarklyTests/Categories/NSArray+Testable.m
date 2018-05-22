//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "NSArray+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagValueCounter+Testable.h"

@implementation NSArray (Testable)
-(NSDictionary*)selectDictionaryMatchingFlagValueCounter:(LDFlagValueCounter*)flagValueCounter {
    if (self.count == 0) { return nil; }
    if (!flagValueCounter) { return nil; }
    NSPredicate *variationPredicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if (![evaluatedObject isKindOfClass:[NSDictionary class]]) { return NO; }
        NSDictionary *evaluatedDictionary = evaluatedObject;
        if (!evaluatedDictionary[kLDFlagValueCounterKeyVariation]) { return NO; }
        if (![evaluatedDictionary[kLDFlagValueCounterKeyVariation] isKindOfClass:[NSNumber class]]) { return NO; }
        return [evaluatedDictionary[kLDFlagValueCounterKeyVariation] integerValue] == flagValueCounter.flagConfigValue.variation;
    }];
    NSArray<NSDictionary*> *selectedCounterDictionaries = [self filteredArrayUsingPredicate:variationPredicate];
    if (selectedCounterDictionaries.count != 1) { return nil; }
    return [selectedCounterDictionaries firstObject];
}
@end

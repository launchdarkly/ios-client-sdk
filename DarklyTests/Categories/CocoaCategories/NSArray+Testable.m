//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "NSArray+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagValueCounter+Testable.h"
#import "LDEventModel+Testable.h"

@implementation NSArray (Testable)
-(NSDictionary*)dictionaryForFlagValueCounter:(LDFlagValueCounter*)flagValueCounter {
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

-(NSDictionary*)dictionaryForEvent:(LDEventModel*)event {
    NSPredicate *eventPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        if (![evaluatedObject isKindOfClass:[NSDictionary class]]) { return NO; }
        NSDictionary *evaluatedEventDictionary = evaluatedObject;
        return [evaluatedEventDictionary[kEventModelKeyKind] isEqualToString:event.kind];
    }];
    NSArray<NSDictionary*> *selectedEventDictionaries = [self filteredArrayUsingPredicate:eventPredicate];
    if (selectedEventDictionaries.count != 1) { return nil; }
    return [selectedEventDictionaries firstObject];
}
@end

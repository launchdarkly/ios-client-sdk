//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "NSArray+UnitTests.h"

@implementation NSArray (UnitTests)
- (NSArray *) flatten {
    NSMutableArray *flattedArray = [NSMutableArray new];
    
    for (id item in self) {
        if ([[item class] isSubclassOfClass:[NSArray class]]) {
            [flattedArray addObjectsFromArray:[item flatten]];
        } else {
            [flattedArray addObject:item];
        }
    }
    
    return flattedArray;
}
@end

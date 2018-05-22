//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagValueCounter;

@interface NSArray (Testable)
-(NSDictionary*)selectDictionaryMatchingFlagValueCounter:(LDFlagValueCounter*)flagValueCounter;
@end

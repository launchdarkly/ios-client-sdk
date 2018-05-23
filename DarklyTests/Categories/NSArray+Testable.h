//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LDFlagValueCounter;
@class LDEventModel;

@interface NSArray (Testable)
-(NSDictionary*)dictionaryForFlagValueCounter:(LDFlagValueCounter*)flagValueCounter;
-(NSDictionary*)dictionaryForEvent:(LDEventModel*)event;
@end

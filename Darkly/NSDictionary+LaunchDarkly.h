//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (LaunchDarkly)
-(nullable NSString*) jsonString;
-(nonnull NSDictionary*)compactMapUsingBlock:(nonnull id _Nonnull (^)(_Nonnull id originalValue))mappingBlock;
@end

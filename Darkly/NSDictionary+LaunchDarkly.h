//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (LaunchDarkly)
-(nullable NSString*) jsonString;
-(nonnull NSDictionary*)compactMapUsingBlock:(nullable id (^)(_Nonnull id originalValue))mappingBlock;
@end

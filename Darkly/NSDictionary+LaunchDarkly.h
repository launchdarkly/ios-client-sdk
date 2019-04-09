//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (LaunchDarkly)
-(nullable NSString*) jsonString;
-(nonnull NSDictionary*)compactMapUsingBlock:(id _Nullable (^_Nullable)(_Nonnull id originalValue))mappingBlock;
@end

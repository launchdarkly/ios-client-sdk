//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "NSDictionary+LaunchDarkly.h"

@implementation NSDictionary (LaunchDarkly)
-(NSString*) jsonString {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
    if (!jsonData) { return nil; }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

-(NSDictionary*)compactMapUsingBlock:(id (^)(id originalValue))mappingBlock {
    NSMutableDictionary *mapped = [NSMutableDictionary dictionaryWithCapacity:self.allKeys.count];
    for (id key in self.allKeys) {
        id mappedValue = mappingBlock(self[key]);
        if (mappedValue == nil) { continue; }
        mapped[key] = mappedValue;
    }
    return [NSDictionary dictionaryWithDictionary:mapped];
}
@end

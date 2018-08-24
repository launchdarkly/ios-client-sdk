//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "NSDictionary+JSON.h"

@implementation NSDictionary (BVJSONString)

-(NSString*) jsonString {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
    if (!jsonData) { return nil; }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
@end

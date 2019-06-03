//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDDataManager.h"
#import "OHPathHelpers.h"
#import "OCMock.h"

@implementation DarklyXCTestCase

- (void)setUp {
    [super setUp];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDictionaryStorageKey];
}

- (void)tearDown {
    if (self.cleanup) { self.cleanup(); }
    [super tearDown];
}

-(void) deleteAllEvents {
}
@end

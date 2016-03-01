//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDDataManager.h"
#import <OHHTTPStubs/OHHTTPStubs.h>
#import <OHPathHelpers.h>
#import <OCMock.h>

@implementation DarklyXCTestCase

- (void)setUp {
    [super setUp];
    
    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"foo" options: 0] ;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"app.launchdarkly.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData: data statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    }];
    

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserDictionaryStorageKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEventDictionaryStorageKey];
}

- (void)tearDown {
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

-(void) deleteAllEvents {
}
@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDRequestManager.h"
#import "LDDataManager.h"

#import <OCMock.h>

@interface LDRequestManagerTest : DarklyXCTestCase
@end

@implementation LDRequestManagerTest
- (void)setUp {
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFeatureFlagRequest {
    
    NSString *apiKey = @"YOUR_MOBILE_KEY";
    NSString *encodedUserString = @"eyJrZXkiOiAiamVmZkB0ZXN0LmNvbSJ9";
    LDRequestManager *requestManager = [LDRequestManager sharedInstance];
    [requestManager setApiKey:apiKey];

    BOOL requestInProgress = YES;
    [requestManager performFeatureFlagRequest:encodedUserString];
    
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
    
    while (requestInProgress == YES && ([timeoutDate timeIntervalSinceNow] > 0)) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
        requestInProgress = [requestManager configRequestInProgress];
    }
    XCTAssertFalse(requestInProgress);
    
}

- (void)testEventRequest {
    
    NSString *apiKey = @"YOUR_MOBILE_KEY";
    
    NSString *jsonEventString = @"[{\"kind\": \"feature\", \"user\": {\"key\" : \"jeff@test.com\", \"custom\" : {\"groups\" : [\"microsoft\", \"google\"]}}, \"creationDate\": 1438468068, \"key\": \"isConnected\", \"value\": true, \"default\": false}]";
    NSData* eventData = [jsonEventString dataUsingEncoding:NSUTF8StringEncoding];
    
    LDRequestManager *requestManager = [LDRequestManager sharedInstance];
    [requestManager setApiKey:apiKey];
    
    BOOL requestInProgress = YES;
    [requestManager performEventRequest:eventData];
    
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
    
    while (requestInProgress == YES && ([timeoutDate timeIntervalSinceNow] > 0)) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
        requestInProgress = [requestManager eventRequestInProgress];
    }
    XCTAssertFalse(requestInProgress);
    
}

@end

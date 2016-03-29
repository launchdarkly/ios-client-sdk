//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDRequestManager.h"
#import "LDDataManager.h"
#import "LDClientManager.h"
#import "LDUserBuilder.h"
#import "LDConfig.h"
#import "LDClient.h"
#import <OCMock.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

@interface LDRequestManagerTest : DarklyXCTestCase
@property (nonatomic) id clientManagerMock;
@property (nonatomic) id ldClientMock;
@property (nonatomic) int tempFlushInterval;
@end

@implementation LDRequestManagerTest
@synthesize clientManagerMock;
@synthesize ldClientMock;
@synthesize tempFlushInterval;

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder = [userBuilder withKey:@"jeff@test.com"];
    LDUserModel *user = [userBuilder build];
    
    LDConfigBuilder *configBuilder = [[LDConfigBuilder alloc] init];
    tempFlushInterval = 30;
    configBuilder = [configBuilder withFlushInterval:tempFlushInterval];
    LDConfig *config = [configBuilder build];
    
    ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    OCMStub([ldClientMock ldUser]).andReturn(user);
    OCMStub([ldClientMock ldConfig]).andReturn(config);
    
    clientManagerMock = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([clientManagerMock sharedInstance])).andReturn(clientManagerMock);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFeatureFlagRequestMakesHttpRequestWithApiKey {
    
    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    __block BOOL httpRequestAttempted = NO;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"" options: 0] ;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"app.launchdarkly.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        httpRequestAttempted = YES;
        [responseArrived fulfill];
        return [OHHTTPStubsResponse responseWithData: data statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    }];
    
    NSString *apiKey = @"YOUR_MOBILE_KEY";
    NSString *encodedUserString = @"eyJrZXkiOiAiamVmZkB0ZXN0LmNvbSJ9";
    LDRequestManager *requestManager = [LDRequestManager sharedInstance];
    [requestManager setApiKey:apiKey];
    [requestManager setBaseUrl:kBaseUrl];
    [requestManager setConnectionTimeout:10];

    [requestManager performFeatureFlagRequest:encodedUserString];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        // By the time we reach this code, the while loop has exited
        // so the response has arrived or the test has timed out
        XCTAssertTrue(httpRequestAttempted);
        [OHHTTPStubs removeAllStubs];
    }];
}

- (void)testEventRequestMakesHttpRequestWithApiKey {
    
    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    __block BOOL httpRequestAttempted = NO;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"" options: 0] ;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"app.launchdarkly.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        httpRequestAttempted = YES;
        [responseArrived fulfill];
        return [OHHTTPStubsResponse responseWithData: data statusCode:200 headers:@{@"Content-Type":@"application/json"}];
    }];
    
    NSString *apiKey = @"YOUR_MOBILE_KEY";
    NSString *jsonEventString = @"[{\"kind\": \"feature\", \"user\": {\"key\" : \"jeff@test.com\", \"custom\" : {\"groups\" : [\"microsoft\", \"google\"]}}, \"creationDate\": 1438468068, \"key\": \"isConnected\", \"value\": true, \"default\": false}]";
    NSData* eventData = [jsonEventString dataUsingEncoding:NSUTF8StringEncoding];
    
    LDRequestManager *requestManager = [LDRequestManager sharedInstance];
    [requestManager setApiKey:apiKey];
    [requestManager setBaseUrl:kBaseUrl];
    [requestManager setConnectionTimeout:10];
    
    [requestManager performEventRequest:eventData];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        // By the time we reach this code, the while loop has exited
        // so the response has arrived or the test has timed out
        XCTAssertTrue(httpRequestAttempted);
        [OHHTTPStubs removeAllStubs];
    }];
}

@end

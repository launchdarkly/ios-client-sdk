//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "OCMock.h"
#import <OHHTTPStubs/OHHTTPStubs.h>

#import "DarklyXCTestCase.h"
#import "LDRequestManager.h"
#import "LDDataManager.h"
#import "LDClientManager.h"
#import "LDUserBuilder.h"
#import "LDConfig.h"
#import "LDConfig+Testable.h"
#import "LDClient.h"

static NSString *const httpMethodGet = @"GET";
static NSString *const testMobileKey = @"testMobileKey";
static NSString *const emptyJson = @"{ }";
static NSString *const flagRequestHost = @"app.launchdarkly.com";
static NSString *const eventRequestHost = @"mobile.launchdarkly.com";
static const int httpStatusCodeOk = 200;
static const int httpStatusCodeUnauthorized = 401;
static const int httpStatusCodeInternalServerError = 500;

@interface LDRequestManagerTest : DarklyXCTestCase
@property (nonatomic) id clientManagerMock;
@property (nonatomic) id ldClientMock;
@end

@implementation LDRequestManagerTest

- (void)setUp {
    [super setUp];
    [OHHTTPStubs removeAllStubs];

    self.ldClientMock = [self mockClientWithUser:[self mockUser] config:[self testConfig]];
    
    id clientManagerMock = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([clientManagerMock sharedInstance])).andReturn(clientManagerMock);
    OCMStub([clientManagerMock isOnline]).andReturn(YES);
    self.clientManagerMock = clientManagerMock;

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [self.ldClientMock stopMocking];
    self.ldClientMock = nil;
    [self.clientManagerMock stopMocking];
    self.clientManagerMock = nil;
    [LDRequestManager sharedInstance].delegate = nil;
    [OHHTTPStubs removeAllStubs];
}

- (void)testPerformFeatureFlagRequest_GetRequest_Success {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
    
    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodGet];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
    }];
}

- (void)testPerformFeatureFlagRequest_GetRequest_Success_invalidData {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg any]];
    [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodGet];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self invalidJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
    }];
}

- (void)testPerformFeatureFlagRequest_GetRequest_DoesNotMakeFallbackRequest {
    NSMutableArray<NSNumber*> *selectedStatusCodes = [NSMutableArray arrayWithArray:[LDClient sharedInstance].ldConfig.flagRetryStatusCodes];
    [selectedStatusCodes addObjectsFromArray:[self selectedNoFallbackStatusCodes]];
    
    for (NSNumber *statusCode in selectedStatusCodes) {
        NSString *getStubName = @"get stub";
        
        __block XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        
        __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
        [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg isNil]];
        [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodGet];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [getRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[statusCode intValue] headers:[self headerForStatusCode:[statusCode intValue]]];
        }].name = getStubName;
        
        [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
            if ([stub.name isEqualToString:getStubName]) {
                [errorResponseArrived fulfill];
            }
        }];
        
        [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
        
        [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
            [requestManagerDelegateMock verifyWithDelay:1]; //By checking the delegate, we are sure a fallback GET isn't called
            
            [LDRequestManager sharedInstance].delegate = nil;
            requestManagerDelegateMock = nil;
            
            getRequestMade = nil;
            errorResponseArrived = nil;
            
            [OHHTTPStubs removeAllStubs];
        }];
    }
}

- (void)testPerformFeatureFlagRequest_ReportRequest_Success {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.useReport = YES;
    
    self.ldClientMock = [self mockClientWithUser:[self mockUser] config:config];
    
    __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

    __weak XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
    __weak XCTestExpectation *responseArrived = [self expectationWithDescription:@"feature flag response arrived"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:kHTTPMethodReport];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        XCTAssertTrue([request.HTTPMethod isEqualToString:kHTTPMethodReport]);
        [responseArrived fulfill];
    }];
    
    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
    }];
}

- (void)testPerformFeatureFlagRequest_ReportRequest_Success_invalidData {
    __weak XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];

    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.useReport = YES;

    self.ldClientMock = [self mockClientWithUser:[self mockUser] config:config];

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg any]];
    [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:kHTTPMethodReport];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self invalidJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
    }];
}

- (void)testPerformFeatureFlagRequest_ReportRequest_MakesFallbackGetRequest {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.useReport = YES;
    
    self.ldClientMock = [self mockClientWithUser:[self mockUser] config:config];
    
    NSArray<NSNumber*> *fallbackStatusCodes = [config flagRetryStatusCodes];
    XCTAssertNotNil(fallbackStatusCodes);
    
    for (NSNumber *fallbackStatusCode in fallbackStatusCodes) {
        NSString *reportStubName = @"report stub";
        NSString *getStubName = @"get stub";
        
        __block XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
        __block XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        __block XCTestExpectation *flagResponseArrived = [self expectationWithDescription:@"feature flag response arrived"];
        
        __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
        [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg isNil]];
        [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:kHTTPMethodReport];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [reportRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[fallbackStatusCode intValue] headers:[self headerForStatusCode:[fallbackStatusCode intValue]]];
        }].name = reportStubName;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodGet];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [getRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [self emptyJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
        }].name = getStubName;
        
        [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
            if ([stub.name isEqualToString:reportStubName]) {
                [errorResponseArrived fulfill];
            }
            if ([stub.name isEqualToString:getStubName]) {
                [flagResponseArrived fulfill];
            }
        }];
        
        [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
        
        [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
            [requestManagerDelegateMock verifyWithDelay:1];
            
            [LDRequestManager sharedInstance].delegate = nil;
            requestManagerDelegateMock = nil;

            reportRequestMade = nil;
            getRequestMade = nil;
            errorResponseArrived = nil;
            flagResponseArrived = nil;

            [OHHTTPStubs removeAllStubs];
        }];
    }
}

- (void)testPerformFeatureFlagRequest_ReportRequest_DoesNotMakeFallbackGetRequest {
    NSArray<NSNumber*> *noFallbackStatusCodes = [self selectedNoFallbackStatusCodes];
    
    for (NSNumber *fallbackStatusCode in noFallbackStatusCodes) {
        LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
        config.useReport = YES;
        
        self.ldClientMock = [self mockClientWithUser:[self mockUser] config:config];

        NSString *reportStubName = @"report stub";
        NSString *getStubName = @"get stub";

        __block XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        
        __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
        [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg isNil]];
        [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:kHTTPMethodReport];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [reportRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[fallbackStatusCode intValue] headers:[self headerForStatusCode:[fallbackStatusCode intValue]]];
        }].name = reportStubName;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [kBaseUrl containsString:request.URL.host] && [request.HTTPMethod isEqualToString:httpMethodGet];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            XCTFail(@"Request Manager made GET flag request in response to a non-fallback status code");
            return [OHHTTPStubsResponse responseWithData: [self emptyJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
        }].name = getStubName;
        
        [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
            if ([stub.name isEqualToString:reportStubName]) {
                [errorResponseArrived fulfill];
            }
        }];
        
        [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
        
        [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
            [requestManagerDelegateMock verifyWithDelay:1];

            [LDRequestManager sharedInstance].delegate = nil;
            requestManagerDelegateMock = nil;
            
            reportRequestMade = nil;
            errorResponseArrived = nil;
            
            [OHHTTPStubs removeAllStubs];
        }];
    }
}

- (void)testPerformFeatureFlagRequestWithoutUser {
    self.ldClientMock = [self mockClientWithUser:nil config:[self testConfig]];
    
    [self mockFlagResponse];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([kBaseUrl containsString:request.URL.host]) {
            XCTFail(@"performFeatureFlagRequest should not make a flag request without a user");
        }
    }];
    
    [[LDRequestManager sharedInstance] performFeatureFlagRequest:nil];
}

- (void)testPerformFeatureFlagRequestOffline {
    self.clientManagerMock = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([self.clientManagerMock sharedInstance])).andReturn(self.clientManagerMock);
    OCMStub([self.clientManagerMock isOnline]).andReturn(NO);

    [self mockFlagResponse];

    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([kBaseUrl containsString:request.URL.host]) {
            XCTFail(@"performFeatureFlagRequest should not make a flag request while offline");
        }
    }];

    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
}

- (void)testFlagRequestPostsClientUnauthorizedNotificationOnUnauthorizedResponse {
    XCTestExpectation *clientUnauthorizedExpection = [self expectationForNotification:kLDClientUnauthorizedNotification object:nil handler:nil];

    [OHHTTPStubs removeAllStubs];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kBaseUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeUnauthorized headers:[self headerForStatusCode:httpStatusCodeUnauthorized]];
    }];
    XCTAssertTrue([OHHTTPStubs allStubs].count == 1);

    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];

    [self waitForExpectations:@[clientUnauthorizedExpection] timeout:10.0];
}

- (void)testFlagRequestDoesNotPostClientUnauthorizedNotificationOnErrorResponse {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kBaseUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeInternalServerError headers:[self headerForStatusCode:httpStatusCodeInternalServerError]];
    }];

    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];

    [clientUnauthorizedObserver verify];
    [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
}

- (void)testEventRequestMakesHttpRequestWithMobileKey {
    
    XCTestExpectation* responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    __block BOOL httpRequestAttempted = NO;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"" options: 0] ;
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"mobile.launchdarkly.com"];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        httpRequestAttempted = YES;
        [responseArrived fulfill];
        return [OHHTTPStubsResponse responseWithData: data statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    [[LDRequestManager sharedInstance] performEventRequest:[self stubEvents]];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        // By the time we reach this code, the while loop has exited
        // so the response has arrived or the test has timed out
        XCTAssertTrue(httpRequestAttempted);
        [OHHTTPStubs removeAllStubs];
    }];
}

- (void)testPerformEventRequestOffline {
    id clientManagerMock = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([clientManagerMock sharedInstance])).andReturn(clientManagerMock);
    OCMStub([clientManagerMock isOnline]).andReturn(NO);
    self.clientManagerMock = clientManagerMock;

    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"" options: 0];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kEventsUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData: data statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([kEventsUrl containsString:request.URL.host]) {
            XCTFail(@"performEventRequest should not make a flag request while offline");
        }
    }];

    [[LDRequestManager sharedInstance] performEventRequest:[self stubEvents]];
}

- (void)testEventRequestPostsClientUnauthorizedNotificationOnUnauthorizedResponse {
    XCTestExpectation *clientUnauthorizedExpection = [self expectationForNotification:kLDClientUnauthorizedNotification object:nil handler:nil];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kEventsUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeUnauthorized headers:[self headerForStatusCode:httpStatusCodeUnauthorized]];
    }];

    [[LDRequestManager sharedInstance] performEventRequest:[self stubEvents]];

    [self waitForExpectations:@[clientUnauthorizedExpection] timeout:10.0];
}

- (void)testEventRequestDoesNotPostClientUnauthorizedNotificationOnErrorResponse {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kEventsUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeInternalServerError headers:[self headerForStatusCode:httpStatusCodeInternalServerError]];
    }];

    [[LDRequestManager sharedInstance] performEventRequest:[self stubEvents]];

    [clientUnauthorizedObserver verify];
    [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
}

#pragma mark - Helpers

- (id)mockClientWithUser:(LDUserModel*)user config:(LDConfig*)config {
    id mockClient = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([mockClient sharedInstance])).andReturn(mockClient);
    OCMStub([mockClient ldUser]).andReturn(user);
    XCTAssertEqual([LDClient sharedInstance].ldUser, user);
    
    if (!config) {
        config = [self testConfig];
    }
    
    OCMStub([mockClient ldConfig]).andReturn(config);
    XCTAssertEqual([LDClient sharedInstance].ldConfig, config);
    
    return mockClient;
}

- (void)mockFlagResponse {
    [OHHTTPStubs removeAllStubs];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[self emptyJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    XCTAssertEqual([OHHTTPStubs allStubs].count, 1);
}

- (LDUserModel*)mockUser {
    LDUserModel *user = [[LDUserModel alloc] init];
    user.key = [[NSUUID UUID] UUIDString];
    user.email = @"jeff@test.com";
    
    return user;
}

- (LDConfig*)testConfig {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    
    return config;
}

- (NSDictionary*)headerForStatusCode:(int)statusCode {
    if (statusCode == httpStatusCodeOk) {
        return @{@"Content-Type":@"application/json"};
    }
    return @{@"Content-Type":@"text"};
}

- (NSData*)emptyJsonData {
    return [[NSData alloc] initWithBase64EncodedString:[LDUtil base64EncodeString:emptyJson] options: 0];
}

- (NSData*)successJsonData {
    return [[NSData alloc] initWithBase64EncodedString:[LDUtil base64EncodeString:@"{\"test-flag\":true}"] options: 0];
}

- (NSData*)invalidJsonData {
    return [[NSData alloc] initWithBase64EncodedString:[LDUtil base64EncodeString:@"invalid json data"] options: 0];
}

- (NSArray<NSNumber*>*)selectedNoFallbackStatusCodes {
    return @[@304, @307, @401, @404, @412, @500];
}

- (NSArray*)stubEvents {
    NSString *jsonEventString = @"[{\"kind\": \"feature\", \"user\": {\"key\" : \"jeff@test.com\", \"custom\" : {\"groups\" : [\"microsoft\", \"google\"]}}, \"creationDate\": 1438468068, \"key\": \"isConnected\", \"value\": true, \"default\": false}]";
    NSData* eventData = [jsonEventString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:eventData options:kNilOptions error:nil];
}

@end

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

static NSString *const httpMethodReport = @"REPORT";
static NSString *const httpMethodGet = @"GET";
static NSString *const testMobileKey = @"testMobileKey";
static NSString *const emptyJson = @"{ }";
static NSString *const flagRequestHost = @"app.launchdarkly.com";
static NSString *const eventRequestHost = @"mobile.launchdarkly.com";
static const int httpStatusCodeOk = 200;

@interface LDRequestManagerTest : DarklyXCTestCase
@property (nonatomic) id clientManagerMock;
@property (nonatomic) id ldClientMock;
@end

@implementation LDRequestManagerTest
@synthesize clientManagerMock;
@synthesize ldClientMock;

- (void)setUp {
    [super setUp];
    
    ldClientMock = [self mockClientWithUser:[self mockUser] config:[self testConfig]];
    
    clientManagerMock = OCMClassMock([LDClientManager class]);
    OCMStub(ClassMethod([clientManagerMock sharedInstance])).andReturn(clientManagerMock);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [LDRequestManager sharedInstance].delegate = nil;
    [OHHTTPStubs removeAllStubs];
}

- (void)testPerformFeatureFlagRequestMakesGetRequestAndCallsDelegateOnSuccess {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
    
    __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
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

- (void)testPerformFeatureFlagRequestDoesNotMakeFallbackRequestWhenUsingGet {
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

- (void)testPerformFeatureFlagRequestMakesReportRequestAndCallsDelegateOnSuccess {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.useReport = YES;
    
    [self mockClientWithUser:[self mockUser] config:config];
    
    __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

    XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
    XCTestExpectation *responseArrived = [self expectationWithDescription:@"feature flag response arrived"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodReport];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        XCTAssertTrue([request.HTTPMethod isEqualToString:httpMethodReport]);
        [responseArrived fulfill];
    }];
    
    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
    }];
}

- (void)testPerformFeatureFlagRequestMakesFallbackGetRequest {
    LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    config.useReport = YES;
    
    [self mockClientWithUser:[self mockUser] config:config];
    
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
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodReport];
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

- (void)testPerformFeatureFlagRequestDoesNotMakeFallbackGetRequest {
    NSArray<NSNumber*> *noFallbackStatusCodes = [self selectedNoFallbackStatusCodes];
    
    for (NSNumber *fallbackStatusCode in noFallbackStatusCodes) {
        LDConfig *config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
        config.useReport = YES;
        
        [self mockClientWithUser:[self mockUser] config:config];

        NSString *reportStubName = @"report stub";
        NSString *getStubName = @"get stub";

        __block XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        
        __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
        [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg isNil]];
        [LDRequestManager sharedInstance].delegate = requestManagerDelegateMock;

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodReport];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [reportRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[fallbackStatusCode intValue] headers:[self headerForStatusCode:[fallbackStatusCode intValue]]];
        }].name = reportStubName;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request.URL.host isEqualToString:flagRequestHost] && [request.HTTPMethod isEqualToString:httpMethodGet];
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

- (void)testPerformFeatureFlagRequestWithoutMobileKey {
    //This test is a little unfair because the LDConfig can't be created without a mobile key, and it's not settable.
    //However the LDRequestManager mobileKey IS settable, and so a client could remove a key after the LDRequestManager is instantiated.
    //The client would probably be trying to break the sdk in that case, so testing it seems appropriate
    [LDRequestManager sharedInstance].mobileKey = nil;
    XCTAssertNil([LDRequestManager sharedInstance].mobileKey);
    
    [self mockFlagResponse];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([request.URL.host isEqualToString:kBaseUrl]) {
            XCTFail(@"performFeatureFlagRequest should not make a flag request without a mobile key");
        }
    }];
    
    [[LDRequestManager sharedInstance] performFeatureFlagRequest:[LDClient sharedInstance].ldUser];
}

- (void)testPerformFeatureFlagRequestWithoutUser {
    [self mockClientWithUser:nil config:[self testConfig]];
    
    [self mockFlagResponse];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([request.URL.host isEqualToString:kBaseUrl]) {
            XCTFail(@"performFeatureFlagRequest should not make a flag request without a user");
        }
    }];
    
    [[LDRequestManager sharedInstance] performFeatureFlagRequest:nil];
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
    
    NSString *jsonEventString = @"[{\"kind\": \"feature\", \"user\": {\"key\" : \"jeff@test.com\", \"custom\" : {\"groups\" : [\"microsoft\", \"google\"]}}, \"creationDate\": 1438468068, \"key\": \"isConnected\", \"value\": true, \"default\": false}]";
    NSData* eventData = [jsonEventString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSArray *eventsArray = [NSJSONSerialization JSONObjectWithData:eventData options:kNilOptions error:nil];
    
    [[LDRequestManager sharedInstance] performEventRequest:eventsArray];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error){
        // By the time we reach this code, the while loop has exited
        // so the response has arrived or the test has timed out
        XCTAssertTrue(httpRequestAttempted);
        [OHHTTPStubs removeAllStubs];
    }];
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
    LDUserBuilder *userBuilder = [[LDUserBuilder alloc] init];
    userBuilder.key = [[NSUUID UUID] UUIDString];
    userBuilder.email = @"jeff@test.com";
    
    return [userBuilder build];
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

- (NSArray<NSNumber*>*)selectedNoFallbackStatusCodes {
    return @[@304, @307, @401, @404, @412, @500];
}

@end

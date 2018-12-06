//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "OCMock.h"
#import <OHHTTPStubs/OHHTTPStubs.h>

#import "DarklyXCTestCase.h"
#import "LDRequestManager.h"
#import "LDRequestManager+Testable.h"
#import "LDRequestManagerDelegateMock.h"
#import "LDConfig.h"
#import "LDConfig+Testable.h"
#import "NSDateFormatter+JsonHeader.h"
#import "NSDateFormatter+JsonHeader+Testable.h"
#import "NSHTTPURLResponse+LaunchDarkly+Testable.h"
#import "LDUtil.h"
#import "NSURLSession+LaunchDarkly.h"

extern NSString * const kEventHeaderLaunchDarklyEventSchema;
extern NSString * const kEventSchema;
extern NSString * const kFlagResponseHeaderEtag;
extern NSString * const kFlagRequestHeaderIfNoneMatch;

static NSString *const httpMethodGet = @"GET";
static NSString *const testMobileKey = @"testMobileKey";
static NSString *const emptyJson = @"{ }";
static NSString *const flagRequestHost = @"app.launchdarkly.com";
static NSString *const eventRequestHost = @"mobile.launchdarkly.com";
NSString * const etagStub = @"com.launchdarkly.test.requestManager.etag";
static const int httpStatusCodeOk = 200;
static const int httpStatusCodeUnauthorized = 401;
static const int httpStatusCodeInternalServerError = 500;

@interface NSURLRequest (LDRequestManagerTest)
@property (copy, nonatomic, readonly) NSString *ifNoneMatchHeader;
-(BOOL)hasHost:(NSString*)host method:(NSString*)method ifNoneMatchHeader:(NSString*)ifNoneMatchHeader cachePolicy:(NSURLRequestCachePolicy)cachePolicy;
@end

@implementation NSURLRequest (LDRequestManagerTest)
-(NSString*)ifNoneMatchHeader {
    return self.allHTTPHeaderFields[kFlagRequestHeaderIfNoneMatch];
}

-(BOOL)hasHost:(NSString*)host method:(NSString*)method ifNoneMatchHeader:(NSString*)ifNoneMatchHeader cachePolicy:(NSURLRequestCachePolicy)cachePolicy {
    return [self.URL.host isEqualToString:host]
        && [self.HTTPMethod isEqualToString:method]
        && ((ifNoneMatchHeader == nil && self.ifNoneMatchHeader == nil) || (ifNoneMatchHeader != nil && [self.ifNoneMatchHeader isEqualToString:ifNoneMatchHeader]))
        && self.cachePolicy == cachePolicy;
}
@end

@interface LDRequestManagerTest : DarklyXCTestCase
@property (nonatomic, strong) LDRequestManager *requestManager;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) id requestManagerDelegateMock;
@end

@implementation LDRequestManagerTest

- (void)setUp {
    [super setUp];
    [OHHTTPStubs removeAllStubs];

    self.config = [self testConfig];
    self.user = [self mockUser];
    [NSURLSession setSharedLDSessionForConfig:self.config];
    self.requestManager = [LDRequestManager requestManagerForMobileKey:self.config.mobileKey config:self.config delegate:nil callbackQueue:nil];
}

- (void)tearDown {
    [self.requestManagerDelegateMock stopMocking];
    self.requestManagerDelegateMock = nil;
    self.requestManager.delegate = nil;
    [OHHTTPStubs onStubActivation:nil];
    [OHHTTPStubs removeAllStubs];
    [super tearDown];
}

- (void)testInitAndConstructRequestManager {
    id requestManagerDelegateMock = [OCMockObject mockForProtocol:@protocol(RequestManagerDelegate)];
    LDConfig *config = [self testConfig];
    dispatch_queue_t completionQueue = dispatch_queue_create("com.launchdarkly.LDRequestManagerTest.completionQueue", DISPATCH_QUEUE_SERIAL);

    self.requestManager = [LDRequestManager requestManagerForMobileKey:config.mobileKey config:config delegate:requestManagerDelegateMock callbackQueue:completionQueue];

    XCTAssertNotNil(self.requestManager);
    XCTAssertEqualObjects(self.requestManager.mobileKey, config.mobileKey);
    XCTAssertEqualObjects(self.requestManager.config, config);
    XCTAssertEqualObjects(self.requestManager.delegate, requestManagerDelegateMock);
    XCTAssertEqualObjects(self.requestManager.callbackQueue, completionQueue);
}

- (void)testPerformFeatureFlagRequest_GetRequest_Success {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
    
    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    self.requestManager.delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
    
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
        XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
    }];
}

- (void)testPerformFeatureFlagRequest_GetRequest_Success_etagExists {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
    self.requestManager.featureFlagEtag = etagStub;

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    self.requestManager.delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:etagStub cachePolicy:NSURLRequestUseProtocolCachePolicy];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[getRequestMade] timeout:1.0];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
}

- (void)testPerformFeatureFlagRequest_GetRequest_Success_CallbackOnSpecifiedQueue {
    XCTestExpectation *delegateCallbackExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.delegateCallbackExpectation",
                                                                                       NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
    dispatch_queue_t callbackQueue = dispatch_queue_create([[NSString stringWithFormat:@"LDRequestManagerTest.%@", NSStringFromSelector(_cmd)] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.requestManager.callbackQueue = callbackQueue;
    LDRequestManagerDelegateMock *requestManagerDelegateMock = [[LDRequestManagerDelegateMock alloc] init];
    requestManagerDelegateMock.processedConfigCallback = ^{
        [delegateCallbackExpectation fulfill];
        XCTAssertFalse([NSThread isMainThread]);
    };
    self.requestManager.delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData: [self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        XCTAssertEqual(requestManagerDelegateMock.processedConfigCallCount, 1);
        XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
    }];
}

- (void)testPerformFeatureFlagRequest_GetRequest_notModified {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:nil];
    self.requestManager.delegate = requestManagerDelegateMock;
    self.requestManager.featureFlagEtag = etagStub;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:etagStub cachePolicy:NSURLRequestUseProtocolCachePolicy];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:(int)kHTTPStatusCodeNotModified headers:[self headerForStatusCode:(int)kHTTPStatusCodeNotModified]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
        XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
    }];
}

- (void)testPerformFeatureFlagRequest_GetRequest_notModified_missingEtag {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:nil];
    self.requestManager.delegate = requestManagerDelegateMock;
    self.requestManager.featureFlagEtag = etagStub;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:etagStub cachePolicy:NSURLRequestUseProtocolCachePolicy];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[NSData data]
                                          statusCode:(int)kHTTPStatusCodeNotModified
                                             headers:[self headerForStatusCode:(int)kHTTPStatusCodeNotModified includeEtag:NO]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[getRequestMade] timeout:1.0];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
}

- (void)testPerformFeatureFlagRequest_GetRequest_Success_invalidData {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg any]];
    self.requestManager.delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[self invalidJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
        [requestManagerDelegateMock verifyWithDelay:1];
        XCTAssertNil(self.requestManager.featureFlagEtag);
    }];
}

- (void)testPerformFeatureFlagRequest_GetRequest_DoesNotMakeFallbackRequest {
    NSMutableArray<NSNumber*> *selectedStatusCodes = [NSMutableArray arrayWithArray:self.config.flagRetryStatusCodes];
    [selectedStatusCodes addObjectsFromArray:[self selectedNoFallbackStatusCodes]];
    
    for (NSNumber *statusCode in selectedStatusCodes) {
        NSString *getStubName = @"get stub";
        
        __block XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        
        __block id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
        [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg isNil]];
        self.requestManager.delegate = requestManagerDelegateMock;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [getRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[statusCode intValue] headers:[self headerForStatusCode:[statusCode intValue]]];
        }].name = getStubName;
        
        [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
            if ([stub.name isEqualToString:getStubName]) {
                [errorResponseArrived fulfill];
            }
        }];
        
        [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
        
        [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
            [requestManagerDelegateMock verifyWithDelay:1]; //By checking the delegate, we are sure a fallback GET isn't called
            XCTAssertNil(self.requestManager.featureFlagEtag);

            self.requestManager.delegate = nil;
            requestManagerDelegateMock = nil;
            
            getRequestMade = nil;
            errorResponseArrived = nil;
            
            [OHHTTPStubs removeAllStubs];
        }];
    }
}

- (void)testPerformFeatureFlagRequest_ReportRequest_Success {
    self.config.useReport = YES;
    
    __block id requestManagerDelegateMock = [OCMockObject mockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    self.requestManager.delegate = requestManagerDelegateMock;

    __weak XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
    __weak XCTestExpectation *responseArrived = [self expectationWithDescription:@"feature flag response arrived"];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        XCTAssertTrue([request.HTTPMethod isEqualToString:kHTTPMethodReport]);
        [responseArrived fulfill];
    }];
    
    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[reportRequestMade, responseArrived] timeout:1];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
}

- (void)testPerformFeatureFlagRequest_ReportRequest_Success_etagExists {
    self.config.useReport = YES;
    self.requestManager.featureFlagEtag = etagStub;

    __block id requestManagerDelegateMock = [OCMockObject mockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
    self.requestManager.delegate = requestManagerDelegateMock;

    __weak XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
    __weak XCTestExpectation *responseArrived = [self expectationWithDescription:@"feature flag response arrived"];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:etagStub cachePolicy:NSURLRequestUseProtocolCachePolicy];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        XCTAssertTrue([request.HTTPMethod isEqualToString:kHTTPMethodReport]);
        [responseArrived fulfill];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[reportRequestMade, responseArrived] timeout:1];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
}

- (void)testPerformFeatureFlagRequest_ReportRequest_Success_invalidData {
    __weak XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];

    self.config.useReport = YES;

    id requestManagerDelegateMock = [OCMockObject mockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg any]];
    self.requestManager.delegate = requestManagerDelegateMock;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData: [self invalidJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[reportRequestMade] timeout:1];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertNil(self.requestManager.featureFlagEtag);
}

- (void)testPerformFeatureFlagRequest_reportRequest_notModified {
    XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
    self.config.useReport = YES;

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:nil];
    self.requestManager.delegate = requestManagerDelegateMock;
    self.requestManager.featureFlagEtag = etagStub;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:etagStub cachePolicy:NSURLRequestUseProtocolCachePolicy];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [reportRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:(int)kHTTPStatusCodeNotModified headers:[self headerForStatusCode:(int)kHTTPStatusCodeNotModified]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[reportRequestMade] timeout:1.0];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
}

- (void)testPerformFeatureFlagRequest_reportRequest_notModified_missingEtag {
    XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
    self.config.useReport = YES;

    id requestManagerDelegateMock = [OCMockObject niceMockForProtocol:@protocol(RequestManagerDelegate)];
    [[requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:nil];
    self.requestManager.delegate = requestManagerDelegateMock;
    self.requestManager.featureFlagEtag = etagStub;

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:etagStub cachePolicy:NSURLRequestUseProtocolCachePolicy];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [getRequestMade fulfill];
        return [OHHTTPStubsResponse responseWithData:[NSData data]
                                          statusCode:(int)kHTTPStatusCodeNotModified
                                             headers:[self headerForStatusCode:(int)kHTTPStatusCodeNotModified includeEtag:NO]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];

    [self waitForExpectations:@[getRequestMade] timeout:1.0];
    [requestManagerDelegateMock verifyWithDelay:1];
    XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);
}

- (void)testPerformFeatureFlagRequest_ReportRequest_MakesFallbackGetRequest {
    self.config.useReport = YES;
    
    //Because the flagRetryStatusCodes are empty, this test doesn't really run. It's here in case LD ever wants to turn this feature on.
    NSArray<NSNumber*> *fallbackStatusCodes = [self.config flagRetryStatusCodes];
    XCTAssertNotNil(fallbackStatusCodes);
    
    for (NSNumber *fallbackStatusCode in fallbackStatusCodes) {
        NSString *reportStubName = @"report stub";
        NSString *getStubName = @"get stub";
        
        __block XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
        __block XCTestExpectation *getRequestMade = [self expectationWithDescription:@"feature flag GET request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        __block XCTestExpectation *flagResponseArrived = [self expectationWithDescription:@"feature flag response arrived"];
        
        self.requestManagerDelegateMock = [OCMockObject mockForProtocol:@protocol(RequestManagerDelegate)];
        [[self.requestManagerDelegateMock expect] processedConfig:YES jsonConfigDictionary:[OCMArg isKindOfClass:[NSDictionary class]]];
        self.requestManager.delegate = self.requestManagerDelegateMock;

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [reportRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[fallbackStatusCode intValue] headers:[self headerForStatusCode:[fallbackStatusCode intValue]]];
        }].name = reportStubName;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [getRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData:[self successJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
        }].name = getStubName;
        
        [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
            if ([stub.name isEqualToString:reportStubName]) {
                [errorResponseArrived fulfill];
            }
            if ([stub.name isEqualToString:getStubName]) {
                [flagResponseArrived fulfill];
            }
        }];
        
        [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
        
        [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
            [self.requestManagerDelegateMock verifyWithDelay:1];
            XCTAssertEqualObjects(self.requestManager.featureFlagEtag, etagStub);

            self.requestManager.delegate = nil;
            self.requestManagerDelegateMock = nil;

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
        self.config.useReport = YES;
        
        NSString *reportStubName = @"report stub";
        NSString *getStubName = @"get stub";

        __block XCTestExpectation *reportRequestMade = [self expectationWithDescription:@"feature flag REPORT request made"];
        __block XCTestExpectation *errorResponseArrived = [self expectationWithDescription:@"feature flag error response arrived"];
        
        __block id requestManagerDelegateMock = [OCMockObject mockForProtocol:@protocol(RequestManagerDelegate)];
        [[requestManagerDelegateMock expect] processedConfig:NO jsonConfigDictionary:[OCMArg isNil]];
        self.requestManager.delegate = requestManagerDelegateMock;

        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request hasHost:flagRequestHost method:kHTTPMethodReport ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            [reportRequestMade fulfill];
            return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:[fallbackStatusCode intValue] headers:[self headerForStatusCode:[fallbackStatusCode intValue]]];
        }].name = reportStubName;
        
        [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
            return [request hasHost:flagRequestHost method:httpMethodGet ifNoneMatchHeader:nil cachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
            XCTFail(@"Request Manager made GET flag request in response to a non-fallback status code");
            return [OHHTTPStubsResponse responseWithData: [self emptyJsonData] statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
        }].name = getStubName;
        
        [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
            if ([stub.name isEqualToString:reportStubName]) {
                [errorResponseArrived fulfill];
            }
        }];
        
        [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
        
        [self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
            [requestManagerDelegateMock verifyWithDelay:1];
            XCTAssertNil(self.requestManager.featureFlagEtag);

            self.requestManager.delegate = nil;
            requestManagerDelegateMock = nil;
            
            reportRequestMade = nil;
            errorResponseArrived = nil;
            
            [OHHTTPStubs removeAllStubs];
        }];
    }
}

- (void)testPerformFeatureFlagRequest_offline {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:flagRequestHost];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        XCTFail(@"Request Manager made feature flag request while offline");
        return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:200 headers:[self headerForStatusCode:200]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:NO];
}

- (void)testPerformFeatureFlagRequest_WithoutMobileKey {
    NSString *nilMobileKey;
    self.requestManager = [LDRequestManager requestManagerForMobileKey:nilMobileKey config:self.config delegate:nil callbackQueue:nil];
    [self mockFlagResponse];
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([kBaseUrl containsString:request.URL.host]) {
            XCTFail(@"performFeatureFlagRequest should not make a flag request without a user");
        }
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
}

- (void)testPerformFeatureFlagRequestWithoutUser {
    [self mockFlagResponse];
    
    [OHHTTPStubs onStubActivation:^(NSURLRequest * _Nonnull request, id<OHHTTPStubsDescriptor>  _Nonnull stub) {
        if ([kBaseUrl containsString:request.URL.host]) {
            XCTFail(@"performFeatureFlagRequest should not make a flag request without a user");
        }
    }];

    LDUserModel *nilUser;
    [self.requestManager performFeatureFlagRequest:nilUser isOnline:YES];
}

- (void)testFlagRequestPostsClientUnauthorizedNotificationOnUnauthorizedResponse {
    XCTestExpectation *notificationExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.notificationExpectation",
                                                                                   NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDClientUnauthorizedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDClientUnauthorizedNotification object:nil userInfo:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        NSDictionary *userInfo = obj;
        [notificationExpectation fulfill];
        return [userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:testMobileKey];
    }]];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    [OHHTTPStubs removeAllStubs];
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kBaseUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeUnauthorized headers:[self headerForStatusCode:httpStatusCodeUnauthorized]];
    }];
    XCTAssertTrue([OHHTTPStubs allStubs].count == 1);

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
    [self waitForExpectations:@[notificationExpectation] timeout:1.0];

    [notificationObserver verify];
}

- (void)testFlagRequestDoesNotPostClientUnauthorizedNotificationOnErrorResponse {
    id clientUnauthorizedObserver = OCMObserverMock();
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
    };
    XCTestExpectation *responseExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.responseExpectation",
                                                                               NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kBaseUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [responseExpectation fulfill];
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeInternalServerError headers:[self headerForStatusCode:httpStatusCodeInternalServerError]];
    }];

    [self.requestManager performFeatureFlagRequest:self.user isOnline:YES];
    [self waitForExpectations:@[responseExpectation] timeout:1.0];

    [clientUnauthorizedObserver verify];
}

- (void)testPerformEventRequest {
    XCTestExpectation* responseArrivedExpectation = [self expectationWithDescription:@"response of async request has arrived"];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"" options: 0] ;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"mobile.launchdarkly.com"] && [[request valueForHTTPHeaderField:kEventHeaderLaunchDarklyEventSchema] isEqualToString:kEventSchema];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:data statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    self.requestManagerDelegateMock = OCMProtocolMock(@protocol(RequestManagerDelegate));
    self.requestManager.delegate = self.requestManagerDelegateMock;
    NSDate *targetHeaderDate = [NSDateFormatter eventDateHeaderStub];
    [[self.requestManagerDelegateMock expect] processedEvents:YES jsonEventArray:[OCMArg isKindOfClass:[NSArray class]] responseDate:[OCMArg checkWithBlock:^BOOL(id obj) {
        XCTAssertEqualObjects(obj, targetHeaderDate);
        [responseArrivedExpectation fulfill];
        return YES;
    }]];

    [self.requestManager performEventRequest:[self stubEvents] isOnline:YES];

    [self waitForExpectations:@[responseArrivedExpectation] timeout:1.0];
    [self.requestManagerDelegateMock verify];
}

- (void)testPerformEventRequest_CallbackOnSpecifiedQueue {
    XCTestExpectation* responseArrivedExpectation = [self expectationWithDescription:@"response of async request has arrived"];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:@"" options: 0] ;
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:@"mobile.launchdarkly.com"] && [[request valueForHTTPHeaderField:kEventHeaderLaunchDarklyEventSchema] isEqualToString:kEventSchema];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:data statusCode:httpStatusCodeOk headers:[self headerForStatusCode:httpStatusCodeOk]];
    }];
    LDRequestManagerDelegateMock *requestManagerDelegateMock = [[LDRequestManagerDelegateMock alloc] init];
    self.requestManager.delegate = requestManagerDelegateMock;
    dispatch_queue_t callbackQueue = dispatch_queue_create([[NSString stringWithFormat:@"LDRequestManagerTest.%@", NSStringFromSelector(_cmd)] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.requestManager.callbackQueue = callbackQueue;
    NSDate *targetHeaderDate = [NSDateFormatter eventDateHeaderStub];
    __weak LDRequestManagerDelegateMock *weakDelegateMock = requestManagerDelegateMock;
    requestManagerDelegateMock.processedEventsCallback = ^{
        __strong LDRequestManagerDelegateMock *strongDelegateMock = weakDelegateMock;
        XCTAssertEqualObjects(strongDelegateMock.processedEventsResponseDate, targetHeaderDate);
        [responseArrivedExpectation fulfill];
        XCTAssertFalse([NSThread isMainThread]);
    };

    [self.requestManager performEventRequest:[self stubEvents] isOnline:YES];

    [self waitForExpectations:@[responseArrivedExpectation] timeout:1.0];
    XCTAssertEqual(requestManagerDelegateMock.processedEventsCallCount, 1);
}

- (void)testEventRequestPostsClientUnauthorizedNotificationOnUnauthorizedResponse {
    XCTestExpectation *notificationExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.notificationExpectation",
                                                                                   NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
    id notificationObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:notificationObserver name:kLDClientUnauthorizedNotification object:nil];
    [[notificationObserver expect] notificationWithName:kLDClientUnauthorizedNotification object:nil userInfo:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[NSDictionary class]]) { return NO; }
        NSDictionary *userInfo = obj;
        [notificationExpectation fulfill];
        return [userInfo[kLDNotificationUserInfoKeyMobileKey] isEqualToString:testMobileKey];
    }]];
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    };

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kEventsUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeUnauthorized headers:[self headerForStatusCode:httpStatusCodeUnauthorized]];
    }];

    [self.requestManager performEventRequest:[self stubEventsWithTag:NSStringFromSelector(_cmd)] isOnline:YES];

    [self waitForExpectations:@[notificationExpectation] timeout:1.0];
    [notificationObserver verify];
}

- (void)testEventRequestDoesNotPostClientUnauthorizedNotificationOnErrorResponse {
    id clientUnauthorizedObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:clientUnauthorizedObserver name:kLDClientUnauthorizedNotification object:nil];
    //it's not obvious, but by not setting expect on the mock observer, the observer will fail when verify is called IF it has received the notification
    self.cleanup = ^{
        [[NSNotificationCenter defaultCenter] removeObserver:clientUnauthorizedObserver];
    };
    XCTestExpectation *responseExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.responseExpectation",
                                                                               NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];

    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [kEventsUrl containsString:request.URL.host];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        [responseExpectation fulfill];
        return [OHHTTPStubsResponse responseWithData:[NSData data] statusCode:httpStatusCodeInternalServerError headers:[self headerForStatusCode:httpStatusCodeInternalServerError]];
    }];

    [self.requestManager performEventRequest:[self stubEventsWithTag:NSStringFromSelector(_cmd)] isOnline:YES];
    [self waitForExpectations:@[responseExpectation] timeout:1.0];

    [clientUnauthorizedObserver verify];
}

- (void)testPerformEventRequest_offline {
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqualToString:eventRequestHost];
    } withStubResponse:^OHHTTPStubsResponse*(NSURLRequest *request) {
        XCTFail(@"Request Manager made event request while offline");
        return [OHHTTPStubsResponse responseWithData: [NSData data] statusCode:200 headers:[self headerForStatusCode:200]];
    }];

    [self.requestManager performEventRequest:[self stubEvents] isOnline:NO];
}

#pragma mark - Helpers

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
    return [self headerForStatusCode:statusCode includeEtag:YES];
}

- (NSDictionary*)headerForStatusCode:(int)statusCode includeEtag:(BOOL)includeEtag {
    if (statusCode == httpStatusCodeOk || statusCode == kHTTPStatusCodeNotModified) {
        NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:@{@"Content-Type":@"application/json", kHeaderKeyDate:kDateHeaderValueDate}];
        if (includeEtag) {
            headers[kFlagResponseHeaderEtag] = etagStub;
        }
        return [headers copy];
    }
    return @{@"Content-Type":@"text", kHeaderKeyDate:kDateHeaderValueDate};
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
    return @[@307, @401, @404, @412, @500];
}

- (NSArray*)stubEvents {
    return [self stubEventsWithTag:nil];
}

- (NSArray*)stubEventsWithTag:(NSString*)tag {
    NSString *jsonEventString = @"[{\"kind\": \"feature\", \"user\": {\"key\" : \"jeff@test.com\", \"custom\" : {\"groups\" : [\"microsoft\", \"google\"]}}, \"creationDate\": 1438468068, \"key\": \"isConnected\", \"value\": true, \"default\": false}]";
    if (tag.length > 0) {
        jsonEventString = [NSString stringWithFormat:@"[{\"kind\": \"feature\", \"user\": {\"key\" : \"jeff@test.com\", \"custom\" : {\"groups\" : [\"microsoft\", \"google\"]}}, \"creationDate\": 1438468068, \"key\": \"isConnected\", \"value\": true, \"default\": false, \"tag\": \"%@\"}]", tag];
    }
    NSData* eventData = [jsonEventString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:eventData options:kNilOptions error:nil];
}

@end

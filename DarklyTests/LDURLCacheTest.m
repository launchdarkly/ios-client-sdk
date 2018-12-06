//
//  LDURLCacheTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 11/16/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDURLCache.h"
#import "OCMock.h"
#import "LDUserModel+Testable.h"
#import "LDRequestManager.h"

static NSString *const testMobileKey = @"testMobileKey";

@interface NSURLRequest (LDURLCacheTest)

@end

@implementation NSURLRequest (LDURLCacheTest)
-(BOOL)hasPropertiesMatchingRequest:(NSURLRequest*)otherRequest {
    return [self.URL.scheme isEqualToString:otherRequest.URL.scheme]
    && [self.URL.host isEqualToString:otherRequest.URL.host]
    && [self.URL.path isEqualToString:otherRequest.URL.path]
    && [self.HTTPMethod isEqualToString:otherRequest.HTTPMethod]
    && ((self.HTTPBody != nil && [self.HTTPBody isEqualToData:otherRequest.HTTPBody]) || (self.HTTPBody == nil && otherRequest.HTTPBody == nil))
    && self.timeoutInterval == otherRequest.timeoutInterval
    && self.cachePolicy == otherRequest.cachePolicy
    && [self.allHTTPHeaderFields isEqualToDictionary:otherRequest.allHTTPHeaderFields];
}
@end

@interface LDRequestManager (LDURLCacheTest)
-(NSURLRequest*)flagRequestUsingReportMethodForUser:(LDUserModel*)user;
-(NSURLRequest*)flagRequestUsingGetMethodForUser:(LDUserModel*)user;
@end

@interface LDURLCache (LDURLCacheTest)
@property (nonatomic, strong) NSURLCache *baseUrlCache;
@end

@implementation LDURLCache (LDURLCacheTest)
@dynamic baseUrlCache;
@end

@interface LDURLCacheTest : DarklyXCTestCase
@property (strong, nonatomic) id nsUrlCacheMock;
@property (nonatomic, strong) LDConfig *config;
@property (nonatomic, strong) LDUserModel *user;
@property (nonatomic, strong) LDRequestManager *requestManager;
@property (nonatomic, strong) NSCachedURLResponse *cachedResponseStub;
@property (strong, nonatomic) LDURLCache *urlCache;
@end

@implementation LDURLCacheTest

-(void)setUp {
    [super setUp];

    self.config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    self.config.streaming = NO;
    self.config.useReport = YES;
    self.user = [LDUserModel stubWithKey:[[NSUUID UUID] UUIDString]];
    self.requestManager = [LDRequestManager requestManagerForMobileKey:testMobileKey config:self.config delegate:nil callbackQueue:nil];
    self.cachedResponseStub = [[NSCachedURLResponse alloc] init];

    self.nsUrlCacheMock = [OCMockObject niceMockForClass:[NSURLCache class]];
    (void)[[[[self.nsUrlCacheMock stub] andReturn:self.nsUrlCacheMock] ignoringNonObjectArgs] initWithMemoryCapacity:0 diskCapacity:0 diskPath:[OCMArg any]];

    self.urlCache = (LDURLCache*)[LDURLCache urlCacheForConfig:self.config usingCache:self.nsUrlCacheMock];
}

-(void)tearDown {
    [super tearDown];
}

-(void)testUrlCacheForConfigUsingCache_streaming_get {
    self.config.streaming = YES;
    self.config.useReport = NO;

    id urlCache = [LDURLCache urlCacheForConfig:self.config usingCache:self.nsUrlCacheMock];

    XCTAssertEqualObjects(urlCache, self.nsUrlCacheMock);
}

-(void)testUrlCacheForConfigUsingCache_streaming_report {
    self.config.streaming = YES;
    self.config.useReport = YES;

    id urlCache = [LDURLCache urlCacheForConfig:self.config usingCache:self.nsUrlCacheMock];

    XCTAssertEqualObjects(urlCache, self.nsUrlCacheMock);
}

-(void)testUrlCacheForConfigUsingCache_polling_get {
    self.config.streaming = NO;
    self.config.useReport = NO;

    id urlCache = [LDURLCache urlCacheForConfig:self.config usingCache:self.nsUrlCacheMock];

    XCTAssertEqualObjects(urlCache, self.nsUrlCacheMock);
}

-(void)testUrlCacheForConfigUsingCache_polling_report {
    self.config.streaming = NO;
    self.config.useReport = YES;

    id urlCache = [LDURLCache urlCacheForConfig:self.config usingCache:self.nsUrlCacheMock];

    XCTAssertNotEqualObjects(urlCache, self.nsUrlCacheMock);
    XCTAssertEqual([urlCache class], [LDURLCache class]);
}

-(void)testUrlCacheForConfigUsingCache_missingBaseCache {
    self.config.streaming = NO;
    self.config.useReport = YES;
    NSURLCache *missingCache;

    id urlCache = [LDURLCache urlCacheForConfig:self.config usingCache:missingCache];

    XCTAssertNil(urlCache);
}

-(void)testShouldUseLDURLCacheForConfig_streaming_get {
    self.config.streaming = YES;
    self.config.useReport = NO;

    XCTAssertFalse([LDURLCache shouldUseLDURLCacheForConfig:self.config]);
}

-(void)testShouldUseLDURLCacheForConfig_streaming_report {
    self.config.streaming = YES;
    self.config.useReport = YES;

    XCTAssertFalse([LDURLCache shouldUseLDURLCacheForConfig:self.config]);
}

-(void)testShouldUseLDURLCacheForConfig_polling_get {
    self.config.streaming = NO;
    self.config.useReport = NO;

    XCTAssertFalse([LDURLCache shouldUseLDURLCacheForConfig:self.config]);
}

-(void)testShouldUseLDURLCacheForConfig_polling_report {
    self.config.streaming = NO;
    self.config.useReport = YES;

    XCTAssertTrue([LDURLCache shouldUseLDURLCacheForConfig:self.config]);
}

-(void)testStoreCachedResponseForDataTask {
    NSURLRequest *reportRequest = [self.requestManager flagRequestUsingReportMethodForUser:self.user];
    NSURLSessionDataTask *reportDataTask = [[NSURLSession sharedSession] dataTaskWithRequest:reportRequest
                                                                           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //Empty because its required, but this should never be executed
    }];
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    [[self.nsUrlCacheMock expect] storeCachedResponse:self.cachedResponseStub forRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        if(![obj isKindOfClass:[NSURLRequest class]]) {
            return NO;
        }
        NSURLRequest *request = obj;
        return [request hasPropertiesMatchingRequest:getRequest];
    }]];

    [self.urlCache storeCachedResponse:self.cachedResponseStub forDataTask:reportDataTask];

    [self.nsUrlCacheMock verify];
}

-(void)testStoreCachedResponseForDataTask_getDataTask {
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    NSURLSessionDataTask *getDataTask = [[NSURLSession sharedSession] dataTaskWithRequest:getRequest
                                                                        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //Empty because its required, but this should never be executed
    }];
    [[self.nsUrlCacheMock expect] storeCachedResponse:self.cachedResponseStub forDataTask:getDataTask];

    [self.urlCache storeCachedResponse:self.cachedResponseStub forDataTask:getDataTask];

    [self.nsUrlCacheMock verify];
}

-(void)testStoreCachedResponseForRequest {
    NSURLRequest *reportRequest = [self.requestManager flagRequestUsingReportMethodForUser:self.user];
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    [[self.nsUrlCacheMock expect] storeCachedResponse:self.cachedResponseStub forRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        if(![obj isKindOfClass:[NSURLRequest class]]) {
            return NO;
        }
        NSURLRequest *request = obj;
        return [request hasPropertiesMatchingRequest:getRequest];
    }]];

    [self.urlCache storeCachedResponse:self.cachedResponseStub forRequest:reportRequest];

    [self.nsUrlCacheMock verify];
}

-(void)testStoreCachedResponseForRequest_getRequest {
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    [[self.nsUrlCacheMock expect] storeCachedResponse:self.cachedResponseStub forRequest:getRequest];   //pass the original request through, it wasn't a REPORT

    [self.urlCache storeCachedResponse:self.cachedResponseStub forRequest:getRequest];

    [self.nsUrlCacheMock verify];
}

-(void)testCachedResponseForRequest {
    NSURLRequest *reportRequest = [self.requestManager flagRequestUsingReportMethodForUser:self.user];
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    [[[self.nsUrlCacheMock expect] andReturn:self.cachedResponseStub] cachedResponseForRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        if(![obj isKindOfClass:[NSURLRequest class]]) {
            return NO;
        }
        NSURLRequest *request = obj;
        return [request hasPropertiesMatchingRequest:getRequest];
    }]];

    NSCachedURLResponse *cachedResponse = [self.urlCache cachedResponseForRequest:reportRequest];

    XCTAssertEqualObjects(cachedResponse, self.cachedResponseStub);
    [self.nsUrlCacheMock verify];
}

-(void)testCachedResponseForRequest_getRequest {
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    [[[self.nsUrlCacheMock expect] andReturn:self.cachedResponseStub] cachedResponseForRequest:getRequest];

    NSCachedURLResponse *cachedResponse = [self.urlCache cachedResponseForRequest:getRequest];

    XCTAssertEqualObjects(cachedResponse, self.cachedResponseStub);
    [self.nsUrlCacheMock verify];
}

-(void)testGetCachedResponseForDataTask {
    NSURLRequest *reportRequest = [self.requestManager flagRequestUsingReportMethodForUser:self.user];
    NSURLSessionDataTask *reportDataTask = [[NSURLSession sharedSession] dataTaskWithRequest:reportRequest
                                                                           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //Empty because its required, but this should never be executed
    }];
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    [[[self.nsUrlCacheMock expect] andReturn:self.cachedResponseStub] cachedResponseForRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        if(![obj isKindOfClass:[NSURLRequest class]]) {
            return NO;
        }
        NSURLRequest *request = obj;
        return [request hasPropertiesMatchingRequest:getRequest];
    }]];
    XCTestExpectation *responseExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.responseExpectation",
                                                                               NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
    __block NSCachedURLResponse *reportedResponse;

    [self.urlCache getCachedResponseForDataTask:reportDataTask completionHandler:^(NSCachedURLResponse * _Nonnull cachedResponse) {
        reportedResponse = cachedResponse;
        [responseExpectation fulfill];
    }];

    [self waitForExpectations:@[responseExpectation] timeout:1.0];
    XCTAssertEqualObjects(reportedResponse, self.cachedResponseStub);
    [self.nsUrlCacheMock verify];
}

-(void)testGetCachedResponseForDataTask_getDataTask {
    NSURLRequest *getRequest = [self.requestManager flagRequestUsingGetMethodForUser:self.user];
    NSURLSessionDataTask *getDataTask = [[NSURLSession sharedSession] dataTaskWithRequest:getRequest
                                                                        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //Empty because its required, but this should never be executed
    }];
    [[self.nsUrlCacheMock expect] getCachedResponseForDataTask:getDataTask completionHandler:[OCMArg invokeBlockWithArgs:self.cachedResponseStub, nil]];
    XCTestExpectation *responseExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.%@.responseExpectation",
                                                                               NSStringFromClass([self class]), NSStringFromSelector(_cmd)]];
    __block NSCachedURLResponse *reportedResponse;

    [self.urlCache getCachedResponseForDataTask:getDataTask completionHandler:^(NSCachedURLResponse * _Nonnull cachedResponse) {
        reportedResponse = cachedResponse;
        [responseExpectation fulfill];
    }];

    [self waitForExpectations:@[responseExpectation] timeout:1.0];
    XCTAssertEqualObjects(reportedResponse, self.cachedResponseStub);
    [self.nsUrlCacheMock verify];
}

@end

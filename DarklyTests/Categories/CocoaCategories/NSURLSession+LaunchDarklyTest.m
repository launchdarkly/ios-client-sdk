//
//  NSURLSession+LaunchDarklyTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 11/19/18.
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDConfig.h"
#import "NSURLSession+LaunchDarkly.h"
#import "LDURLCache.h"

static NSString * const testMobileKey = @"com.launchdarkly.test.nsurlsession+launchdarkly";

@interface NSURLSession (NSURLSession_LaunchDarklyTest)
@property (strong, nonatomic, readonly) NSURLCache *urlCache;
@property (assign, nonatomic, readonly) BOOL hasLDURLCache;
@end

@implementation NSURLSession (NSURLSession_LaunchDarklyTest)
@dynamic hasLDURLCache;
-(NSURLCache*)urlCache {
    return self.configuration.URLCache;
}
@end

@interface NSURLSession_LaunchDarklyTest : DarklyXCTestCase
@property (nonatomic, strong) LDConfig *config;
@end

@implementation NSURLSession_LaunchDarklyTest

-(void)setUp {
    self.config = [[LDConfig alloc] initWithMobileKey:testMobileKey];
    self.config.streaming = NO;
    self.config.useReport = YES;
}

-(void)tearDown {

}

-(void)testSetSharedLDSessionForConfig_streaming_get {
    self.config.streaming = YES;
    self.config.useReport = NO;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_streaming_get_updated {
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];
    self.config.streaming = YES;
    self.config.useReport = NO;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_streaming_get_unchanged {
    self.config.streaming = YES;
    self.config.useReport = NO;
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_streaming_report {
    self.config.streaming = YES;
    self.config.useReport = YES;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_streaming_report_updated {
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];
    self.config.streaming = YES;
    self.config.useReport = YES;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_streaming_report_unchanged {
    self.config.streaming = YES;
    self.config.useReport = YES;
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_polling_get {
    self.config.streaming = NO;
    self.config.useReport = NO;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_polling_get_updated {
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];
    self.config.streaming = NO;
    self.config.useReport = NO;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_polling_get_unchanged {
    self.config.streaming = NO;
    self.config.useReport = NO;
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertFalse([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_polling_report {
    self.config.streaming = NO;
    self.config.useReport = YES;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertTrue([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_polling_report_updated {
    self.config.streaming = YES;
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];
    self.config.streaming = NO;
    self.config.useReport = YES;

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertNotEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertTrue([NSURLSession sharedLDSession].hasLDURLCache);
}

-(void)testSetSharedLDSessionForConfig_polling_report_unchanged {
    [NSURLSession setSharedLDSessionForConfig:self.config];
    NSURLSession *originalSession = [NSURLSession sharedLDSession];

    [NSURLSession setSharedLDSessionForConfig:self.config];

    XCTAssertNotNil([NSURLSession sharedLDSession]);
    XCTAssertEqual([NSURLSession sharedLDSession], originalSession);
    XCTAssertNotNil([NSURLSession sharedLDSession].urlCache);
    XCTAssertTrue([NSURLSession sharedLDSession].hasLDURLCache);
}

@end

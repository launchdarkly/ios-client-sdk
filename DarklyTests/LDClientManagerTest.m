//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDClientManager.h"
#import "LDUserBuilder.h"
#import "LDClient.h"
#import <OCMock.h>
#import "LDRequestManager.h"
#import "LDDataManager.h"
#import "LDEventModel.h"

@interface LDClientManagerTest : DarklyXCTestCase
@property (nonatomic) id requestManagerMock;
@property (nonatomic) id ldClientMock;
@property (nonatomic) id dataManagerMock;
@end


@implementation LDClientManagerTest
@synthesize requestManagerMock;
@synthesize ldClientMock;
@synthesize dataManagerMock;

- (void)setUp {
    [super setUp];
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder = [builder withKey:@"jeff@test.com"];
    LDUserModel *user = [builder build];
    
    ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    OCMStub([ldClientMock ldUser]).andReturn(user);
    
    requestManagerMock = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([requestManagerMock sharedInstance])).andReturn(requestManagerMock);
    
    dataManagerMock = OCMClassMock([LDDataManager class]);
    OCMStub(ClassMethod([dataManagerMock sharedManager])).andReturn(dataManagerMock);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [ldClientMock stopMocking];
    [requestManagerMock stopMocking];
    [dataManagerMock stopMocking];
}

- (void)testSyncWithServerForConfigWhenUserExists {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [clientManager syncWithServerForConfig];

    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg isKindOfClass:[NSString class]]]);
}

- (void)testDoNotSyncWithServerForConfigWhenUserDoesNotExists {
    NSData *testData = nil;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    [clientManager syncWithServerForConfig];
    
    [requestManagerMock verify];
}

- (void)testSyncWithServerForEventsWhenEventsExist {
    NSData *testData = [[NSData alloc] init];
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    [clientManager syncWithServerForEvents];
    
    OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
    
}

- (void)testDoNotSyncWithServerForEventsWhenEventsDoNotExist {
    NSData *testData = nil;
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    [clientManager syncWithServerForEvents];
    
    [requestManagerMock verify];
    
}

- (void)testSyncWithServerForEventsNotProcessedWhenOffline {
    NSData *testData = [[NSData alloc] init];
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];    
    [clientManager syncWithServerForEvents];
    
    [requestManagerMock verify];
}

- (void)testEventsExistPerformRequestWhenFlushCalled {
    NSData *testData = [[NSData alloc] init];
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    [clientManager flushEvents];
    
    OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:testData]]);
}

- (void)testEventsDoNotExistDoNotPerformRequestWhenFlushCalled {
    NSData *testData = nil;
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    [clientManager flushEvents];
    
    [requestManagerMock verify];
}

- (void)testSyncWithServerForEventsNotProcessedWhenOfflineWhenFlushCalled {
    NSData *testData = [[NSData alloc] init];
    OCMStub([dataManagerMock allEventsJsonData]).andReturn(testData);
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isEqual:testData]];
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];
    [clientManager flushEvents];
    
    [requestManagerMock verify];
}
@end

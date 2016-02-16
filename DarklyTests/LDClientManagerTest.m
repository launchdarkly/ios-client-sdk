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
@property (nonatomic) NSData *jsonData;
@property (nonatomic) id requestManagerMock;
@property (nonatomic) id ldClientMock;
@end


@implementation LDClientManagerTest
@synthesize jsonData;
@synthesize requestManagerMock;
@synthesize ldClientMock;

- (void)setUp {
    [super setUp];
    LDUserBuilder *builder = [[LDUserBuilder alloc] init];
    builder = [builder withKey:@"jeff@test.com"];
    LDUserModel *user = [builder build];
    
    LDEventModel *event = [[LDEventModel alloc] init];
    [event featureEventWithKey:@"blah" keyValue:NO defaultKeyValue:NO userValue:user];
    
    ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    OCMStub([ldClientMock user]).andReturn(user);
    
    requestManagerMock = OCMClassMock([LDRequestManager class]);
    OCMStub(ClassMethod([requestManagerMock sharedInstance])).andReturn(requestManagerMock);
    OCMStub([requestManagerMock performFeatureFlagRequest:[OCMArg isKindOfClass:[NSString class]]]);
    OCMStub([requestManagerMock performEventRequest:[OCMArg any]]);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [ldClientMock stopMocking];
    [requestManagerMock stopMocking];
}

- (void)testSyncWithServerForConfig {
    // {"lastName":null, "firstName":null, "anonymous":false, "key":"jeff@test.com", "avatar":null,
    //        "os":"80400", "ip":null, "custom":null, "config":null, "country":null, "email":null,
    //    "device":"iPhone"}
    NSString *encodedUserString = @"ewogICJrZXkiIDogImplZmZAdGVzdC5jb20iLAogICJjdXN0b20iIDogewoKICB9LAogICJ1cGRhdGVkQXQiIDogIjIwMTYtMDItMTQiLAogICJkZXZpY2UiIDogImlQaG9uZSIsCiAgIm9zIiA6ICI5LjIiCn0=";
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [clientManager syncWithServerForConfig];

    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg isEqual:encodedUserString]]);
}

- (void)testSyncWithServerForEvents {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    OCMStub([self.dataManagerMock allEventsJsonData]).andReturn(jsonData);
    
    [clientManager syncWithServerForEvents];
    
    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg isEqual:jsonData]]);
    
}

- (void)testSyncWithServerForConfigNotProcessedWhenOffline {
    // {"lastName":null, "firstName":null, "anonymous":false, "key":"jeff@test.com", "avatar":null,
    //        "os":"80400", "ip":null, "custom":null, "config":null, "country":null, "email":null,
    //    "device":"iPhone"}
    NSString *encodedUserString = @"eyJsYXN0TmFtZSI6bnVsbCwiZmlyc3ROYW1lIjpudWxsLCJhbm9ueW1vdXMiOmZhbHNlLCJrZXkiOiJqZWZmQHRlc3QuY29tIiwiYXZhdGFyIjpudWxsLCJvcyI6IjgwNDAwIiwiaXAiOm51bGwsImN1c3RvbSI6bnVsbCwiY29uZmlnIjpudWxsLCJjb3VudHJ5IjpudWxsLCJlbWFpbCI6bnVsbCwiZGV2aWNlIjoiaVBob25lIn0=";
    
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];
    
    [clientManager syncWithServerForConfig];
    
    [requestManagerMock verify];
}


- (void)testSyncWithServerForEventsNotProcessedWhenOffline {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];    
    [clientManager syncWithServerForEvents];
    
    [requestManagerMock verify];
}

- (void)testSyncWithServerForEventsWhenFlushCalled {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    [clientManager flushEvents];
    
    OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:jsonData]]);
    
}

- (void)testSyncWithServerForEventsNotProcessedWhenOfflineWhenFlushCalled {
    LDClientManager *clientManager = [LDClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isKindOfClass:[NSData class]]];
    
    [clientManager flushEvents];
    
    [requestManagerMock verify];
}
@end

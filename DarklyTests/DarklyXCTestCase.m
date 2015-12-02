//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "LDDataManager.h"
#import "DataManager+UniteTests.h"


@implementation DarklyXCTestCase
@synthesize dataManagerMock;

- (void)setUp {
    [super setUp];
    dataManagerMock = [LDDataManager createMockIfNil];

}

- (void)tearDown {
    [super tearDown];
    [dataManagerMock nilify];
    [self deleteAllEvents];
    
    dataManagerMock = nil;
}

-(void) deleteAllEvents {
    NSFetchRequest *allEvents = [[NSFetchRequest alloc] init];
    NSManagedObjectContext *context = [dataManagerMock managedObjectContext];
    [allEvents setEntity:[NSEntityDescription entityForName:@"EventEntity" inManagedObjectContext: context]];
    [allEvents setIncludesPropertyValues:NO];
    
    NSError *error = nil;
    NSArray *events = [context executeFetchRequest:allEvents error:&error];
    
    for (NSManagedObject *event in events) {
        [context deleteObject:event];
    }
    [dataManagerMock saveContext];
    
    [dataManagerMock setEventCreatedCount: 0];
}
@end

//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DataManager+UniteTests.h"
#import "LDDataManager.h"

#import <OCMock.h>

@implementation LDDataManager (UniteTests)
static LDDataManager *mockedSharedAPIManager = nil;


+(instancetype)createMockIfNil {
    LDDataManager *manager = [LDDataManager swizzled_sharedManager];
    if (!mockedSharedAPIManager) {
        mockedSharedAPIManager = [OCMockObject partialMockForObject:manager];
        
        
        NSURL *modelURL = [[NSBundle bundleForClass:[LDDataManager class]] URLForResource:@"darkly"                                                                      withExtension:@"momd"];
        NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
        
        NSAssert(store, @"Should have a store by now");
        
        NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        moc.persistentStoreCoordinator = psc;
        
        // stubbing
        OCMStub([mockedSharedAPIManager persistentStoreCoordinator]).andReturn(psc);
        OCMStub([mockedSharedAPIManager managedObjectModel]).andReturn(mom);
        OCMStub([mockedSharedAPIManager managedObjectContext]).andReturn(moc);
    }
    
    return mockedSharedAPIManager;
}


+ (id)sharedManager {
    return [self createMockIfNil];
}

+ (id)swizzled_sharedManager {
    static LDDataManager *sharedAPIManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAPIManager = [[self alloc] init];
    });
    return sharedAPIManager;
}

-(void)nilify {
    mockedSharedAPIManager = nil;
}

+ (void)load {
    static dispatch_once_t once_token;
    dispatch_once(&once_token,  ^{
        SEL sharedManagerSelector = @selector(sharedManager);
        SEL swizzledSharedManagerSelector = @selector(swizzled_sharedManager);
        Method originalMethod = class_getInstanceMethod(self, sharedManagerSelector);
        Method extendedMethod = class_getInstanceMethod(self, swizzledSharedManagerSelector);
 
        method_exchangeImplementations(originalMethod, extendedMethod);

        
        SEL saveContextSelector = @selector(saveContext);
        SEL swizzledSaveContextSelector = @selector(swizzeldSaveContext);
        originalMethod = class_getInstanceMethod(self, saveContextSelector);
        extendedMethod = class_getInstanceMethod(self, swizzledSaveContextSelector);
        
        method_exchangeImplementations(originalMethod, extendedMethod);
    });
}

- (void)swizzeldSaveContext {
    NSError *error = nil;
    
    if (![[self managedObjectContext] save:&error])
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
}
@end

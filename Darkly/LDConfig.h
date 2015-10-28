//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

@interface LDConfig : NSObject {
    
}

@property (nonatomic) NSString* apiKey;
@property (nonatomic) NSString* baseUrl;
@property (nonatomic) NSNumber* capacity;
@property (nonatomic) NSNumber* connectionTimeout;
@property (nonatomic) NSNumber* flushInterval;
@property (nonatomic) BOOL debugEnabled;

@end

@interface LDConfigBuilder : NSObject {
    
}

- (LDConfigBuilder *)withApiKey:(NSString *)apiKey;
- (LDConfigBuilder *)withBaseUrl:(NSString *)baseUrl;
- (LDConfigBuilder *)withCapacity:(int)capacity;
- (LDConfigBuilder *)withConnectionTimeout:(int)connectionTimeout;
- (LDConfigBuilder *)withFlushInterval:(int)flushInterval;
- (LDConfigBuilder *)withDebugEnabled:(BOOL)debugEnabled;

-(LDConfig *)build;

@end

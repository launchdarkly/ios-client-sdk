//
//  LDEventSource.m
//  LDEventSource
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import "LDEventSource.h"
#import <CoreGraphics/CGBase.h>

static CGFloat const ES_RETRY_INTERVAL = 1.0;
static CGFloat const ES_DEFAULT_TIMEOUT = 300.0;
static CGFloat const ES_MAX_RECONNECT_TIME = 3600.0;

static NSString *const ESKeyValueDelimiter = @":";
static NSString *const LDEventSeparatorLFLF = @"\n\n";
static NSString *const LDEventSeparatorCRCR = @"\r\r";
static NSString *const LDEventSeparatorCRLFCRLF = @"\r\n\r\n";
static NSString *const LDEventKeyValuePairSeparator = @"\n";

static NSString *const LDEventDataKey = @"data";
static NSString *const LDEventIDKey = @"id";
static NSString *const LDEventEventKey = @"event";
static NSString *const LDEventRetryKey = @"retry";
NSString *const LDEventSourceErrorDomain = @"LDEventSourceErrorDomain";

static NSInteger const HTTPStatusCodeUnauthorized = 401;

@interface LDEventSource () <NSURLSessionDataDelegate> {
    BOOL wasClosed;
    dispatch_queue_t messageQueue;
    dispatch_queue_t connectionQueue;
}

@property (nonatomic, strong) NSURL *eventURL;
@property (nonatomic, strong) NSURLSessionDataTask *eventSourceTask;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *listeners;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@property (nonatomic, assign) NSInteger retryAttempt;
@property (readonly, nonatomic, strong) NSDictionary <NSString *, NSString *> *httpRequestHeaders;
@property (nonatomic, strong) NSString *connectMethod;
@property (nonatomic, strong) NSData *connectBody;
@property (nonatomic, strong) id lastEventID;

- (void)_open;
- (void)_dispatchEvent:(LDEvent *)e;

@end

@implementation LDEventSource

+ (instancetype)eventSourceWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers
{
    return [[LDEventSource alloc] initWithURL:URL httpHeaders:headers];
}

+ (instancetype)eventSourceWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*)headers connectMethod:(NSString*)connectMethod connectBody:(NSData*)connectBody
{
    return [[LDEventSource alloc] initWithURL:URL httpHeaders:headers timeoutInterval:ES_DEFAULT_TIMEOUT connectMethod:connectMethod connectBody:connectBody];
}

+ (instancetype)eventSourceWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*)headers timeoutInterval:(NSTimeInterval)timeoutInterval connectMethod:(NSString*)connectMethod connectBody:(NSData*)connectBody
{
    return [[LDEventSource alloc] initWithURL:URL httpHeaders:headers timeoutInterval:timeoutInterval connectMethod:connectMethod connectBody:connectBody];
}

- (instancetype)initWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers
{
    return [self initWithURL:URL httpHeaders:headers timeoutInterval:ES_DEFAULT_TIMEOUT connectMethod:@"GET" connectBody:nil];
}

- (instancetype)initWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers connectMethod:(NSString*)connectMethod connectBody:(NSData*)connectBody
{
    return [self initWithURL:URL httpHeaders:headers timeoutInterval:ES_DEFAULT_TIMEOUT connectMethod:connectMethod connectBody:connectBody];
}

- (instancetype)initWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers timeoutInterval:(NSTimeInterval)timeoutInterval connectMethod:(NSString*)connectMethod connectBody:(NSData*)connectBody
{
    self = [super init];
    if (self) {
        _listeners = [NSMutableDictionary dictionary];
        _eventURL = URL;
        _timeoutInterval = timeoutInterval;
        _retryInterval = ES_RETRY_INTERVAL;
        _retryAttempt = 0;
        _httpRequestHeaders = headers;
        _connectMethod = connectMethod;
        _connectBody = connectBody;
        messageQueue = dispatch_queue_create("com.launchdarkly.eventsource-queue", DISPATCH_QUEUE_SERIAL);
        connectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_retryInterval * NSEC_PER_SEC));
        dispatch_after(popTime, connectionQueue, ^(void){
            [self _open];
        });
    }
    return self;
}

- (void)addEventListener:(NSString *)eventName handler:(LDEventSourceEventHandler)handler
{
    if (self.listeners[eventName] == nil) {
        [self.listeners setObject:[NSMutableArray array] forKey:eventName];
    }
    
    [self.listeners[eventName] addObject:handler];
}

- (void)onMessage:(LDEventSourceEventHandler)handler
{
    [self addEventListener:MessageEvent handler:handler];
}

- (void)onError:(LDEventSourceEventHandler)handler
{
    [self addEventListener:ErrorEvent handler:handler];
}

- (void)onOpen:(LDEventSourceEventHandler)handler
{
    [self addEventListener:OpenEvent handler:handler];
}

- (void)onReadyStateChanged:(LDEventSourceEventHandler)handler
{
    [self addEventListener:ReadyStateEvent handler:handler];
}

- (void)close
{
    wasClosed = YES;
    [self.eventSourceTask cancel];
    [self.session finishTasksAndInvalidate];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200) {
        // Opened
        LDEvent *e = [LDEvent new];
        e.readyState = kEventStateOpen;
        
        _retryAttempt = 0;
        [self _dispatchEvent:e type:ReadyStateEvent];
        [self _dispatchEvent:e type:OpenEvent];
    }
    
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    NSString *eventString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [eventString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    LDEvent *event = [LDEvent new];
    event.readyState = kEventStateOpen;
    
    for (NSString *line in lines) {
        if ([line hasPrefix:ESKeyValueDelimiter]) {
            continue;
        }
        
        if (!line || line.length == 0) {
            dispatch_async(messageQueue, ^{
                [self _dispatchEvent:event];
            });
            
            event = [LDEvent new];
            event.readyState = kEventStateOpen;
            continue;
        }
        
        @autoreleasepool {
            NSScanner *scanner = [NSScanner scannerWithString:line];
            scanner.charactersToBeSkipped = [NSCharacterSet whitespaceCharacterSet];
            
            NSString *key, *value;
            [scanner scanUpToString:ESKeyValueDelimiter intoString:&key];
            [scanner scanString:ESKeyValueDelimiter intoString:nil];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&value];
            
            if (key && value) {
                if ([key isEqualToString:LDEventEventKey]) {
                    event.event = value;
                } else if ([key isEqualToString:LDEventDataKey]) {
                    if (event.data != nil) {
                        event.data = [event.data stringByAppendingFormat:@"\n%@", value];
                    } else {
                        event.data = value;
                    }
                } else if ([key isEqualToString:LDEventIDKey]) {
                    event.id = value;
                    self.lastEventID = event.id;
                } else if ([key isEqualToString:LDEventRetryKey]) {
                    self.retryInterval = [value doubleValue];
                }
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    self.eventSourceTask = nil;
    
    if (wasClosed) {
        return;
    }
    
    LDEvent *e = [LDEvent new];
    e.readyState = kEventStateClosed;
    e.error = [self eventErrorForTask:task errorCode:e.readyState underlyingError:error];
    
    [self _dispatchEvent:e type:ReadyStateEvent];
    [self _dispatchEvent:e type:ErrorEvent];
    
    if (![self responseIsUnauthorizedForTask:task]) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)([self increaseIntervalWithBackoff] * NSEC_PER_SEC));
        dispatch_after(popTime, connectionQueue, ^(void){
            [self _open];
        });
    }
}

- (NSError*)eventErrorForTask:(nonnull NSURLSessionTask *)task errorCode:(NSInteger)errorCode underlyingError:(nullable NSError *)underlyingError
{
    NSError *defaultError = underlyingError ?: [NSError errorWithDomain:@""
                                                       code:errorCode
                                                   userInfo:@{ NSLocalizedDescriptionKey: @"Connection with the event source was closed." }];

    if (![self responseIsUnauthorizedForTask:task]) { return defaultError; }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{NSLocalizedDescriptionKey: @"Connection refused by the server."}];
    if (underlyingError) { userInfo[NSUnderlyingErrorKey] = underlyingError; }
    NSError *eventError = [NSError errorWithDomain:LDEventSourceErrorDomain
                                              code:-HTTPStatusCodeUnauthorized
                                          userInfo:userInfo.copy];

    return eventError;
}

- (BOOL)responseIsUnauthorizedForTask:(nonnull NSURLSessionTask *)task
{
    if (![task.response isKindOfClass:[NSHTTPURLResponse class]]) { return NO; }
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
    return response && response.statusCode == HTTPStatusCodeUnauthorized;
}

- (void)_open
{
    wasClosed = NO;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.eventURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:self.timeoutInterval];
    if (self.httpRequestHeaders) {
        for (NSString * key in self.httpRequestHeaders.allKeys){
            [request setValue:self.httpRequestHeaders[key] forHTTPHeaderField:key];
        }
    }
    if (self.lastEventID) {
        [request setValue:self.lastEventID forHTTPHeaderField:@"Last-Event-ID"];
    }

    if (self.connectMethod.length > 0) {
        request.HTTPMethod = self.connectMethod;
    }

    if (self.connectBody.length > 0) {
        request.HTTPBody = self.connectBody;
    }
    
    if (self.session) {
        [self.session invalidateAndCancel];
    }
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue currentQueue]];
    
    self.eventSourceTask = [self.session dataTaskWithRequest:request];
    [self.eventSourceTask resume];
    
    LDEvent *e = [LDEvent new];
    e.readyState = kEventStateConnecting;
    
    [self _dispatchEvent:e type:ReadyStateEvent];
    
    if (![NSThread isMainThread]) {
        CFRunLoopRun();
    }
}

- (void)_dispatchEvent:(LDEvent *)event type:(NSString * const)type
{
    NSArray *errorHandlers = self.listeners[type];
    for (LDEventSourceEventHandler handler in errorHandlers) {
        dispatch_async(connectionQueue, ^{
            handler(event);
        });
    }
}

- (void)_dispatchEvent:(LDEvent *)event
{
    [self _dispatchEvent:event type:MessageEvent];
    
    if (event.event != nil) {
        [self _dispatchEvent:event type:event.event];
    }
}

- (CGFloat)increaseIntervalWithBackoff {
    _retryAttempt++;
    return arc4random_uniform(MIN(ES_MAX_RECONNECT_TIME, _retryInterval * pow(2, _retryAttempt)));
}

@end


@implementation LDEvent

- (NSString *)description
{
    NSString *state = nil;
    switch (self.readyState) {
            case kEventStateConnecting:
            state = @"CONNECTING";
            break;
            case kEventStateOpen:
            state = @"OPEN";
            break;
            case kEventStateClosed:
            state = @"CLOSED";
            break;
    }
    
    return [NSString stringWithFormat:@"<%@: readyState: %@, id: %@; event: %@; data: %@>",
            [self class],
            state,
            self.id,
            self.event,
            self.data];
}

@end

NSString *const MessageEvent = @"message";
NSString *const ErrorEvent = @"error";
NSString *const OpenEvent = @"open";
NSString *const ReadyStateEvent = @"readyState";

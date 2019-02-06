//
//  LDEventSource.h
//  LDEventSource
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kEventStateConnecting = 0,
    kEventStateOpen = 1,
    kEventStateClosed = 2,
} LDEventState;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LDEventSourceErrorDomain;

// ---------------------------------------------------------------------------------------------------------------------

/// Describes an Event received from an EventSource
@interface LDEvent : NSObject <NSCopying>

/// The Event ID
@property (nonatomic, strong, nullable) id id;
/// The name of the Event
@property (nonatomic, strong, nullable) NSString *event;
/// The data received from the EventSource
@property (nonatomic, strong, nullable) NSString *data;

/// The current state of the connection to the EventSource
@property (nonatomic, assign) LDEventState readyState;
/// Provides details of any errors with the connection to the EventSource
@property (nonatomic, strong, nullable) NSError *error;

-(id)copyWithZone:(nullable NSZone*)zone;
@end

// ---------------------------------------------------------------------------------------------------------------------

typedef void (^LDEventSourceEventHandler)(LDEvent * _Nullable event);

// ---------------------------------------------------------------------------------------------------------------------

/// Connect to and receive Server-Sent Events (SSEs).
@interface LDEventSource : NSObject

/// Returns a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
+ (instancetype)eventSourceWithURL:(NSURL *)URL httpHeaders:(nullable NSDictionary<NSString*, NSString *>*) headers;

/// Returns a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
/// @param connectMethod The http method to use to connect to the EventSource. Default: GET
/// @param connectBody The http body to use to connect to the EventSource. Default: nil
+ (instancetype)eventSourceWithURL:(NSURL *)URL
                       httpHeaders:(nullable NSDictionary<NSString*, NSString *>*)headers
                     connectMethod:(nullable NSString*)connectMethod
                       connectBody:(nullable NSData*)connectBody;

/// Returns a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
/// @param timeoutInterval The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
/// @param connectMethod The http method to use to connect to the EventSource. Default: GET
/// @param connectBody The http body to use to connect to the EventSource. Default: nil
+ (instancetype)eventSourceWithURL:(NSURL *)URL
                       httpHeaders:(nullable NSDictionary<NSString*, NSString *>*)headers
                   timeoutInterval:(NSTimeInterval)timeoutInterval
                     connectMethod:(nullable NSString*)connectMethod
                       connectBody:(nullable NSData*)connectBody;

/// Creates a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
- (instancetype)initWithURL:(NSURL *)URL httpHeaders:(nullable NSDictionary<NSString*, NSString *>*) headers;

/// Creates a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
/// @param connectMethod The http method to use to connect to the EventSource. Default: GET
/// @param connectBody The http body to use to connect to the EventSource. Default: nil
- (instancetype)initWithURL:(NSURL *)URL
                httpHeaders:(nullable NSDictionary<NSString*, NSString *>*)headers
              connectMethod:(nullable NSString*)connectMethod
                connectBody:(nullable NSData*)connectBody;

/// Creates a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
/// @param timeoutInterval The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
/// @param connectMethod The http method to use to connect to the EventSource. Default: GET
/// @param connectBody The http body to use to connect to the EventSource. Default: nil
- (instancetype)initWithURL:(NSURL *)URL
                httpHeaders:(nullable NSDictionary<NSString*, NSString *>*)headers
            timeoutInterval:(NSTimeInterval)timeoutInterval
              connectMethod:(nullable NSString*)connectMethod
                connectBody:(nullable NSData*)connectBody;

/// Registers an event handler for the Message event.
///
/// @param handler The handler for the Message event.
- (void)onMessage:(LDEventSourceEventHandler)handler;

/// Registers an event handler for the Error event.
///
/// @param handler The handler for the Error event.
- (void)onError:(LDEventSourceEventHandler)handler;

/// Registers an event handler for the Open event.
///
/// @param handler The handler for the Open event.
- (void)onOpen:(LDEventSourceEventHandler)handler;

- (void)onReadyStateChanged:(LDEventSourceEventHandler)handler;

/// Registers an event handler for a named event.
///
/// @param eventName The name of the event you registered.
/// @param handler The handler for the Message event.
- (void)addEventListener:(NSString *)eventName handler:(LDEventSourceEventHandler)handler;

/// Opens the connection to the EventSource.
- (void)open;

/// Closes the connection to the EventSource.
- (void)close;

@end

// ---------------------------------------------------------------------------------------------------------------------

extern NSString *const MessageEvent;
extern NSString *const ErrorEvent;
extern NSString *const OpenEvent;
extern NSString *const ReadyStateEvent;

NS_ASSUME_NONNULL_END

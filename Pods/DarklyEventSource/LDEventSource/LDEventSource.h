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

// ---------------------------------------------------------------------------------------------------------------------

/// Describes an Event received from an EventSource
@interface LDEvent : NSObject

/// The Event ID
@property (nonatomic, strong) id id;
/// The name of the Event
@property (nonatomic, strong) NSString *event;
/// The data received from the EventSource
@property (nonatomic, strong) NSString *data;

/// The current state of the connection to the EventSource
@property (nonatomic, assign) LDEventState readyState;
/// Provides details of any errors with the connection to the EventSource
@property (nonatomic, strong) NSError *error;

@end

// ---------------------------------------------------------------------------------------------------------------------

typedef void (^LDEventSourceEventHandler)(LDEvent *event);

// ---------------------------------------------------------------------------------------------------------------------

/// Connect to and receive Server-Sent Events (SSEs).
@interface LDEventSource : NSObject

/// Returns a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
+ (instancetype)eventSourceWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers;

/// Returns a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
/// @param timeoutInterval The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
+ (instancetype)eventSourceWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers timeoutInterval:(NSTimeInterval)timeoutInterval;

/// Creates a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
- (instancetype)initWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers;

/// Creates a new instance of EventSource with the specified URL.
///
/// @param URL The URL of the EventSource.
/// @param headers The http headers to be included
/// @param timeoutInterval The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
- (instancetype)initWithURL:(NSURL *)URL httpHeaders:(NSDictionary<NSString*, NSString *>*) headers timeoutInterval:(NSTimeInterval)timeoutInterval;

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

/// Closes the connection to the EventSource.
- (void)close;

@end

// ---------------------------------------------------------------------------------------------------------------------

extern NSString *const MessageEvent;
extern NSString *const ErrorEvent;
extern NSString *const OpenEvent;
extern NSString *const ReadyStateEvent;

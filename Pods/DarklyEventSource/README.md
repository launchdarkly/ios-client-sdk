# EventSource
**Server-Sent Events for iOS, watchOS, tvOS and macOS**

![Travis](https://travis-ci.org/neilco/EventSource.svg?branch=master)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/DarklyEventSource.svg)](https://img.shields.io/cocoapods/v/DarklyEventSource.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/AFNetworking.svg?style=flat)](http://cocoadocs.org/docsets/AFNetworking)

For details on Server Sent Events, see the [Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)

## What does it do?

It creates a long-lived, unidirectional HTTP channel between your Cocoa app and a web server so that your app can receive events from the server. 

#### Listening for Named Events

Subscribing to a _named event_ is done via the `addEventListener:handler:` method, as shown below:

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source addEventListener:@"hello_event" handler:^(Event *e) {
    NSLog(@"%@: %@", e.event, e.data);
}];
```

It's super simple and will be familiar to anyone who has seen any Server-Sent Events JavaScript code.

#### Listening for All Events

There's a `onMessage:` method that will receive all message events from the server. 

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source onMessage:^(Event *e) {
    NSLog(@"%@: %@", e.event, e.data);
}];
```

#### Listening for Connection State Changes

Additionally, there are `onOpen:`, `onMessage`, `onError:`, and `onReadyStateChanged:` methods to receive connection state events.

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source onError:^(Event *e) {
    NSLog(@"ERROR: %@", e.data);
}];
```

With the exception of the `onError:`, the `event` and `data` properties for these events will be `null`. Check the `readyState` property on the event. 

#### Graceful Connection Handling

To make the initial connection to the streaming event server, call `open` on the event source. That gives you control over when events start arriving.

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source onMessage:^(Event *e) {
    NSLog(@"%@: %@", e.event, e.data);
}];
[source open];
```

Reconnection attempts are automatic and seamless, even if the server goes down. How frequently reconnection attempts are made is controlled by the server by setting the `retry` key on its events. If the server doesn't send a retry, the default is 1 second intervals. 

### Server Code

This is a simple [Node.js](http://nodejs.org/) app that will generate the Server-Sent Events. The events are created at a rate of one per second.

```
var http = require('http');

http.createServer(function (req, res) {
    res.writeHead(200, { 'Transfer-Encoding': 'chunked', 'Content-Type': 'text/event-stream' });
 
    setInterval(function() { 
        var now = new Date().getTime();
        var payload = 'event: hello_event\ndata: {"message":"' + now + '"}\n\n'; 
        res.write(payload); 
    }, 1000);
}).listen(8000);
```

The payload above doesn't include an `id` parameter, but if you include one it will be available in the `Event` object in your Cocoa code.

## Installation
EventSource supports multiple methods for installing the library in a project.

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like EventSource in your projects. You can install it with the following command:

```bash
$ gem install cocoapods
```
#### Podfile

To integrate EventSource into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TargetName' do
pod 'DarklyEventSource', '~> 4.0.1'
end
```

Then, run the following command:

```bash
$ pod install
```

### Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate EventSource into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "launchdarkly/ios-eventsource" >= 4.0.1
```

Run `carthage` to build the framework and drag the built `EventSource.framework` into your Xcode project.

### Contact

[Neil Cowburn](http://github.com/neilco)  
[@neilco](https://twitter.com/neilco)

## License

[MIT license](http://neil.mit-license.org)

Copyright (c) 2013 Neil Cowburn (http://github.com/neilco/)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

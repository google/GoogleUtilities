/* Copyright 2010 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  GTMHTTPServer.h
//
//  This is a *very* *simple* webserver that can be built into something, it is
//  not meant to stand up a site, it sends all requests to its delegate for
//  processing on the main thread.  It does not support pipelining, etc.  It's
//  great for places where you need a simple webserver to unittest some code
//  that hits a server.
//
//  NOTE: there are several TODOs left in here as markers for things that could
//  be done if one wanted to add more to this class.
//
//  Based a little on HTTPServer, part of the CocoaHTTPServer sample code found at
//  https://opensource.apple.com/source/HTTPServer/HTTPServer-11/CocoaHTTPServer/
//  License for the CocoaHTTPServer sample code:
//
//  Software License Agreement (BSD License)
//
//  Copyright (c) 2011, Deusty, LLC
//  All rights reserved.
//
//  Redistribution and use of this software in source and binary forms,
//  with or without modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above
//  copyright notice, this list of conditions and the
//  following disclaimer.
//
//  * Neither the name of Deusty nor the names of its
//  contributors may be used to endorse or promote products
//  derived from this software without specific prior
//  written permission of Deusty, LLC.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.

#import <Foundation/Foundation.h>

#if GTM_IPHONE_SDK
#import <CFNetwork/CFNetwork.h>
#endif  // GTM_IPHONE_SDK

// Global constants needed for errors from start

#undef _EXTERN
#undef _INITIALIZE_AS
#ifdef GTMHTTPSERVER_DEFINE_GLOBALS
#define _EXTERN
#define _INITIALIZE_AS(x) = x
#else
#define _EXTERN extern
#define _INITIALIZE_AS(x)
#endif

_EXTERN NSString *const kGTMHTTPServerErrorDomain
    _INITIALIZE_AS(@"com.google.mactoolbox.HTTPServerDomain");
enum {
  kGTMHTTPServerSocketCreateFailedError = -100,
  kGTMHTTPServerBindFailedError = -101,
  kGTMHTTPServerListenFailedError = -102,
  kGTMHTTPServerHandleCreateFailedError = -103,
};

@class GTMHTTPRequestMessage, GTMHTTPResponseMessage;

// ----------------------------------------------------------------------------

// See comment at top of file for the intended use of this class.
@interface GTMHTTPServer : NSObject {
 @private
  id delegate_;  // WEAK
  uint16_t port_;
  BOOL reusePort_;
  BOOL localhostOnly_;
  NSFileHandle *listenHandle_;
  NSMutableArray *connections_;
}

// The delegate must support the httpServer:handleRequest: method in
// NSObject(GTMHTTPServerDelegateMethods) below.
- (id)initWithDelegate:(id)delegate;

- (id)delegate;

// Passing port zero will let one get assigned.
- (uint16_t)port;
- (void)setPort:(uint16_t)port;

// Controls listening socket behavior: SO_REUSEADDR vs SO_REUSEPORT.
// The default is NO (SO_REUSEADDR)
- (BOOL)reusePort;
- (void)setReusePort:(BOOL)reusePort;

// Receive connections on the localHost loopback address only or on all
// interfaces for this machine.  The default is to only listen on localhost.
- (BOOL)localhostOnly;
- (void)setLocalhostOnly:(BOOL)yesno;

// Start/Stop the web server.  If there is an error starting up the server, |NO|
// is returned, and the specific startup failure can be returned in |error| (see
// above for the error domain and error codes).  If the server is started, |YES|
// is returned and the server's delegate is called for any requests that come
// in.
- (BOOL)start:(NSError **)error;
- (void)stop;

// returns the number of requests currently active in the server (i.e.-being
// read in, sent replies).
- (NSUInteger)activeRequestCount;

@end

@interface NSObject (GTMHTTPServerDelegateMethods)
- (GTMHTTPResponseMessage *)httpServer:(GTMHTTPServer *)server
                         handleRequest:(GTMHTTPRequestMessage *)request;
@end

// ----------------------------------------------------------------------------

// Encapsulates an http request, one of these is sent to the server's delegate
// for each request.
@interface GTMHTTPRequestMessage : NSObject {
 @private
  CFHTTPMessageRef message_;
}
- (NSString *)version;
- (NSURL *)URL;
- (NSString *)method;
- (NSData *)body;
- (NSDictionary *)allHeaderFieldValues;
@end

// ----------------------------------------------------------------------------

// Encapsulates an http response, the server's delegate should return one for
// each request received.
@interface GTMHTTPResponseMessage : NSObject {
 @private
  CFHTTPMessageRef message_;
}
+ (instancetype)responseWithString:(NSString *)plainText;
+ (instancetype)responseWithHTMLString:(NSString *)htmlString;
+ (instancetype)responseWithBody:(NSData *)body
                     contentType:(NSString *)contentType
                      statusCode:(int)statusCode;
+ (instancetype)emptyResponseWithCode:(int)statusCode;
// TODO: class method for redirections?
// TODO: add helper for expire/no-cache
- (void)setValue:(NSString *)value forHeaderField:(NSString *)headerField;
- (void)setHeaderValuesFromDictionary:(NSDictionary *)dict;
@end

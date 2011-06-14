// Copyright 2009 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import "KSServer.h"

// Key into an out-of-band data dictionary.  Value is an NSNumber-wrapped
// integer which is the number of seconds since midnight, server-time.
#define KSOmahaServerSecondsSinceMidnightKey @"SecondsSinceMidnight"

@class KSStatsCollection;
@class KSClientActives;

// Do Omaha specific things for creating NSURLRequests and responses.
// For example, this class converts KSTickets into XML requests for an
// Omaha server, and knows how to convert an Omaha XML response into
// KSUpdateActions.
@interface KSOmahaServer : KSServer {
 @private
  NSXMLElement *root_;  // weak
  NSXMLDocument *document_;
  KSClientActives *actives_;
  int secondsSinceMidnight_;
}

// Return an autoreleased KSOmahaServer which points to the given URL.
// |params| is a dictionary of parameters as defined by our owner, or
// nil to use defaults.  |engine| is an update engine whose delegate
// may be called, or use nil to not use one.
// See KSUpdateEngineParameters.h for the keys.  Defaults are generally
// not what you want except for unit testing.
+ (id)serverWithURL:(NSURL *)url params:(NSDictionary *)params;
+ (id)serverWithURL:(NSURL *)url params:(NSDictionary *)params
             engine:(KSUpdateEngine *)engine;

// Initializer that uses default params for cases where we don't care
// (e.g. unit tests).
+ (id)serverWithURL:(NSURL *)url;

// Returns an NSURLRequest object to use for uploading the |stats| to the
// Omaha sever specified by |url|. The NSURLRequest object represents a POST
// with an XML body containing all the stats from |stats|.
- (NSURLRequest *)requestForStats:(KSStatsCollection *)stats;

@end

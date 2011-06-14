// Copyright 2008 Google Inc.
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


@class KSUpdateEngine;

// KSServer
//
// *Abstract* class for dealing with specific types of "UpdateEngine servers".
// Subclasses will contain all of the information specific to a given
// UpdateEngine server type. Subclasses should be able to create one or more
// NSURLRequest objects for a specific server from the list of tickets. They
// must also be able to convert from an NSURLResponse and a blob of data into an
// array of KSUpdateInfos representing the response from the server in a server
// agnostic way. A "KSServer" represents a specific instance (because of the
// URL) of some type of server.
//
// See also KSUpdateInfo.h
@interface KSServer : NSObject {
 @private
  NSURL *url_;
  NSDictionary *params_;
  KSUpdateEngine *engine_;
}

// Initializes the KSSever instance with the specified |url| and nil params.
- (id)initWithURL:(NSURL *)url;

// The |url| is the address where the server resides,
// and |params| is an optional dictionary of values associated with this server
// instance. |params| can be any dictionary of key/value pairs. There are no
// standard or required keys, and they're only interpreted by the specific
// KSServer subclass. KSServer subclasses that require specific keys must
// document those keys. The |url| argument is required, |params| is optional.
- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params;

// Designated initializer.  Like -initWithURL:params, but also pass in
// the UpdateEngine that's controlling the whole process.  This is so
// we can return server-specific information via a delegate method.
- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params
           engine:(KSUpdateEngine *)engine;

// Returns the URL of this server.
- (NSURL *)url;

// Returns the parameters used when creating this server instance.
// Returns nil if they were not provided.
- (NSDictionary *)params;

// Returns the update engine that is responsible for the current update.
// Returns nil if it was not provided.
- (KSUpdateEngine *)engine;

// Returns an array of NSURLRequest objects for the given |tickets|.
// Array may contain only one request, or may be nil.
- (NSArray *)requestsForTickets:(NSArray *)tickets;

// Returns an array of KSUpdateInfo dictionaries representing the results from a
// server in a server agnostic way. The keys for the dictionaries are declared
// in KSUpdateInfo.h.
// |oob| is an NSDictionary of out-of-band data, chunks of information
// from the server class that are outside of the data for each
// upadate.
// If there is no OOB data, |*oob| will be assigned to nil.  It is valid to
// to pass NULL if you're not interested in OOB data.
// Subclasses should override this.
- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob;

// Returns a pretty-printed version of the specified response and data.
- (NSString *)prettyPrintResponse:(NSURLResponse *)response
                             data:(NSData *)data;

@end

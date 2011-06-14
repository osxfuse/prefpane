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

#import "KSServer.h"

#import "KSUpdateEngine.h"

@implementation KSServer

- (id)init {
  return [self initWithURL:nil];
}

- (id)initWithURL:(NSURL *)url {
  return [self initWithURL:url params:nil];
}

- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params {
  return [self initWithURL:url params:params engine:nil];
}

- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params
           engine:(KSUpdateEngine *)engine {
  if ((self = [super init])) {
    if (url == nil) {
      [self release];
      return nil;
    }
    url_ = [url retain];
    params_ = [params copy];
    engine_ = [engine retain];
  }
  return self;
}

- (void)dealloc {
  [url_ release];
  [params_ release];
  [engine_ release];
  [super dealloc];
}

- (NSURL *)url {
  return url_;
}

- (NSDictionary *)params {
  return params_;
}

- (KSUpdateEngine *)engine {
  return engine_;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p url=%@, params=%@>",
          [self class], self, url_, params_];
}


//
// "Abstract" methods.
//


// Subclasses to override.
- (NSArray *)requestsForTickets:(NSArray *)tickets {
  return nil;
}

// Subclasses can override if they supply OOB information.  Otherwise
// the default will turn around and use -updateInfosForResponse:data
- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob {
  if (oob) *oob = NULL;
  return nil;
}

- (NSString *)prettyPrintResponse:(NSURLResponse *)response
                             data:(NSData *)data {
  return nil;
}

@end

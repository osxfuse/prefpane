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

#import "KSMockFetcherFactory.h"


// Base class for mock fetchers, to be used in place of GDataHTTPFetcher.
@interface KSMockFetcher : NSObject {
  NSURLRequest *request_;
  id delegate_;
  SEL finishedSelector_;
  SEL failedWithErrorSelector_;
}
- (id)initWithURLRequest:(NSURLRequest *)request;

// Let's try and look like a GDataHTTPFetcher; at least enough
// to fool KSUpdateChecker.
- (BOOL)beginFetchWithDelegate:(id)delegate
             didFinishSelector:(SEL)finishedSEL
               didFailSelector:(SEL)networkFailedSEL;
- (NSURLResponse *)response;

// subclasses should override this, to perform a "response" on the run loop.
- (void)invoke;

// so unit tests are happy
- (BOOL)isFetching;
- (void)stopFetching;
@end


// Fetcher which always claims to finish correctly, returning the
// given data.
@interface KSMockFetcherFinishWithData : KSMockFetcher {
  NSData *data_;
}
- (id)initWithURLRequest:(NSURLRequest *)request data:(NSData *)data;
- (void)invoke;
@end


// Fetcher which always fails with an error.
@interface KSMockFetcherFailWithError : KSMockFetcher {
  NSError *error_;
}
- (id)initWithURLRequest:(NSURLRequest *)request error:(NSError *)error;
- (void)invoke;
@end


/* --------------------------------------------------------------- */

@implementation KSMockFetcher

- (id)initWithURLRequest:(NSURLRequest *)request {
  if ((self = [super init]) != nil) {
    request_ = [request retain];
  }
  return self;
}

- (void)dealloc {
  [request_ release];
  [delegate_ release];
  [super dealloc];
}

- (BOOL)beginFetchWithDelegate:(id)delegate
             didFinishSelector:(SEL)finishedSEL
               didFailSelector:(SEL)networkFailedSEL {
  delegate_ = [delegate retain];
  finishedSelector_ = finishedSEL;
  failedWithErrorSelector_ = networkFailedSEL;
  NSArray *modes = [NSArray arrayWithObject:NSDefaultRunLoopMode];
  [[NSRunLoop currentRunLoop] performSelector:@selector(invoke) target:self
                                     argument:nil
                                        order:0
                                        modes:modes];
  return YES;
}

- (NSURLResponse *)response {
  // KSUpdateChecker asks for this but ignores it's value.
  // Let's return something legit-looking so it's happy.
  NSURL *url = [NSURL URLWithString:@"http://foo.bar"];
  return [[[NSURLResponse alloc] initWithURL:url
                                    MIMEType:@"text"
                       expectedContentLength:0
                            textEncodingName:nil] autorelease];
}

// COV_NF_START
- (void)invoke {
  // Can't do this unless we derive from SenTestCase
  // STAssertNotNil(nil, nil);  // fail if not overridden
  _GTMDevAssert(0, @"invoke must be overridden");  // COV_NF_LINE
}
// COV_NF_END

- (BOOL)isFetching {
  return YES;  // a lie
}

- (void)stopFetching {
  // noop
}

@end


/* --------------------------------------------------------------- */
@implementation KSMockFetcherFinishWithData

- (id)initWithURLRequest:(NSURLRequest *)request data:(NSData *)data {
  if ((self = [super initWithURLRequest:request]) != nil) {
    data_ = [data retain];
  }
  return self;
}

- (void)dealloc {
  [data_ release];
  [super dealloc];
}

- (void)invoke {
  [delegate_ performSelector:finishedSelector_
                  withObject:self
                  withObject:data_];
}

@end


/* --------------------------------------------------------------- */
@implementation KSMockFetcherFailWithError

- (id)initWithURLRequest:(NSURLRequest *)request error:(NSError *)error {
  if ((self = [super initWithURLRequest:request]) != nil) {
    error_ = [error retain];
  }
  return self;
}

- (void)dealloc {
  [error_ release];
  [super dealloc];
}

- (void)invoke {
  [delegate_ performSelector:failedWithErrorSelector_
                  withObject:self
                  withObject:error_];
}

@end


/* --------------------------------------------------------------- */

@interface KSMockFetcherFactory (Private)
- (id)initWithClass:(Class)class arg1:(id)arg1 arg2:(id)arg2 status:(int)status;
@end


@implementation KSMockFetcherFactory (Private)

- (id)initWithClass:(Class)class arg1:(id)arg1 arg2:(id)arg2 status:(int)status {
  if ((self = [super init]) != nil) {
    class_ = class;
    arg1_ = [arg1 retain];
    arg2_ = [arg2 retain];
    status_ = status;
  }
  return self;
}

@end


@implementation KSMockFetcherFactory

+ (KSMockFetcherFactory *)alwaysFinishWithData:(NSData *)data {
  return [[[KSMockFetcherFactory alloc]
           initWithClass:[KSMockFetcherFinishWithData class]
            arg1:data arg2:nil status:0] autorelease];
}

+ (KSMockFetcherFactory *)alwaysFailWithError:(NSError *)error {
  return [[[KSMockFetcherFactory alloc]
           initWithClass:[KSMockFetcherFailWithError class]
            arg1:error arg2:nil status:0] autorelease];
}

- (void)dealloc {
  [arg1_ release];
  [arg2_ release];
  [super dealloc];
}

- (GDataHTTPFetcher *)createFetcherForRequest:(NSURLRequest *)request {
  if (class_ == [KSMockFetcherFinishWithData class]) {
    return [[[KSMockFetcherFinishWithData alloc] initWithURLRequest:request
                                                                  data:arg1_]
             autorelease];
  } else if (class_ == [KSMockFetcherFailWithError class]) {
    return [[[KSMockFetcherFailWithError alloc] initWithURLRequest:request
                                                             error:arg1_]
             autorelease];
  } else {
    _GTMDevAssert(0, @"can't decide what to mock");  // COV_NF_LINE
    return nil;  // COV_NF_LINE
  }
}



@end




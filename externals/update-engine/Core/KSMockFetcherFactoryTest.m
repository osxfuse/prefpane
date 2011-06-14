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

#import <SenTestingKit/SenTestingKit.h>
#import "KSMockFetcherFactory.h"
#import "GDataHTTPFetcher.h"
#import "KSFetcherFactory.h"


@interface KSMockFetcherFactory (TestingFriend)
- (id)initWithClass:(Class)class arg1:(id)arg1 arg2:(id)arg2 status:(int)status;
@end


@interface KSMockFetcherFactoryTest : SenTestCase {
  NSData *fetchedData_;
  NSError *fetchError_;
}
@end


@implementation KSMockFetcherFactoryTest

- (void)tearDown {
  [fetchedData_ release];
  fetchedData_ = nil;
  [fetchError_ release];
  fetchError_ = nil;
}

- (void)fetcher:(GDataHTTPFetcher *)fetcher finishedWithData:(NSData *)data {
  fetchedData_ = [data retain];
}

- (void)fetcher:(GDataHTTPFetcher *)fetcher failedWithError:(NSError *)error {
  fetchError_ = [error retain];
}

- (void)testDataFetcher {
  // Put some data into the mock fetcher and make sure we get that data out,
  // along with non-failure.
  const char *string = "Hoff";
  NSData *data = [NSData dataWithBytes:string length:strlen(string)];
  KSFetcherFactory *factory = [KSMockFetcherFactory alwaysFinishWithData:data];

  NSURL *url = [NSURL URLWithString:@"http://google.com"];
  NSURLRequest *req = [NSURLRequest requestWithURL:url];
  GDataHTTPFetcher *fetcher = [factory createFetcherForRequest:req];

  [fetcher beginFetchWithDelegate:self
                didFinishSelector:@selector(fetcher:finishedWithData:)
                  didFailSelector:@selector(fetcher:failedWithError:)];
  // Let the fetcher do its thing.
  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:0.2];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];

  STAssertNil(fetchError_, nil);
  STAssertNotNil(fetchedData_, nil);
  STAssertTrue(strcmp([fetchedData_ bytes], string) == 0, nil);
}

- (void)testErrorFetcher {
  NSError *error = [[[NSError alloc] init] autorelease];
  KSFetcherFactory *factory = [KSMockFetcherFactory alwaysFailWithError:error];

  NSURL *url = [NSURL URLWithString:@"http://google.com"];
  NSURLRequest *req = [NSURLRequest requestWithURL:url];
  GDataHTTPFetcher *fetcher = [factory createFetcherForRequest:req];

  [fetcher beginFetchWithDelegate:self
                didFinishSelector:@selector(fetcher:finishedWithData:)
                  didFailSelector:@selector(fetcher:failedWithError:)];
  // Let the fetcher do its thing.
  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:0.2];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];

  STAssertNotNil(fetchError_, nil);
  STAssertEquals(fetchError_, error, nil);
  STAssertNil(fetchedData_, nil);
}

@end


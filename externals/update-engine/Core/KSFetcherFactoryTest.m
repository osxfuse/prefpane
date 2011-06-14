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

#import <SenTestingKit/SenTestingKit.h>
#import "KSFetcherFactory.h"
#import "GDataHTTPFetcher.h"


@interface KSFetcherFactoryTest : SenTestCase
@end


@implementation KSFetcherFactoryTest

- (void)testCreation {
  KSFetcherFactory *factory = [KSFetcherFactory factory];
  STAssertNotNil(factory, nil);
  int count = 20;
  for (int x = 0; x < count; x++) {
    NSString *urlString = [NSString stringWithFormat:@"http://google-%d.com", x];
    NSURL *url = [NSURL URLWithString:urlString];
    GDataHTTPFetcher *fetcher = [factory createFetcherForRequest:
                                        [NSURLRequest requestWithURL:url]];
    STAssertNotNil(fetcher, nil);
  }
}

@end



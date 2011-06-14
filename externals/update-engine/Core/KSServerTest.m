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
#import "KSServer.h"


@interface KSServerTest : SenTestCase
@end


@implementation KSServerTest

- (void)testCreation {

  KSServer *s = [[KSServer alloc] initWithURL:nil];
  STAssertNil(s, nil);
  
  s = [[KSServer alloc] init];
  STAssertNil(s, nil);

  s = [[KSServer alloc] initWithURL:[NSURL URLWithString:@"http://foo"]];
  STAssertNotNil(s, nil);
  STAssertEqualObjects([s url], [NSURL URLWithString:@"http://foo"], nil);
  STAssertNil([s params], nil);
  [s release];

  NSURL *url = [NSURL URLWithString:@"http://www.foo.com:8000/file.txt"];
  STAssertNotNil(url, nil);
  s = [[KSServer alloc] initWithURL:url];
  STAssertNotNil(s, nil);
  STAssertEqualObjects([s url], url, nil);
  STAssertNil([s params], nil);
  STAssertTrue([[s description] length] > 1, nil);
  [s release];

  NSDictionary *params = [NSDictionary dictionaryWithObject:@"a" forKey:@"b"];
  s = [[KSServer alloc] initWithURL:url params:params];
  STAssertNotNil(s, nil);
  STAssertEqualObjects([s url], url, nil);
  STAssertNotNil([s params], nil);
  STAssertEqualObjects([s params], params, nil);
  STAssertTrue([[s description] length] > 1, nil);
  [s release];
}

- (void)testAbstractMethods {
  NSURL *url = [NSURL URLWithString:@"http://www.foo.com:8000/file.txt"];
  STAssertNotNil(url, nil);
  KSServer *s = [[[KSServer alloc] initWithURL:url] autorelease];
  STAssertNotNil(s, nil);
  STAssertNil([s requestsForTickets:nil], nil);
  STAssertNil([s requestsForTickets:[NSMutableArray arrayWithCapacity:1]], nil);
  NSData *data = [NSData dataWithBytes:(void *)"hi mom" length:6];
  STAssertNil([s updateInfosForResponse:nil data:data outOfBandData:NULL], nil);
  STAssertNil([s updateInfosForResponse:nil data:nil outOfBandData:NULL], nil);
  STAssertNil([s updateInfosForResponse:nil data:data outOfBandData:NULL], nil);
  STAssertNil([s updateInfosForResponse:nil data:nil outOfBandData:NULL], nil);
  NSDictionary *oob;
  STAssertNil([s updateInfosForResponse:nil data:nil outOfBandData:&oob], nil);
  STAssertNil(oob, nil);
}

@end



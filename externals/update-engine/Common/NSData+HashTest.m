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
#import "NSData+Hash.h"
#import "GTMBase64.h"


@interface NSData_HashTest : SenTestCase
@end


@implementation NSData_HashTest

- (void)testBasics {
  NSData *hash;
  NSString *hashString;
  NSString *expectedHash;

  // Empty data.
  NSData *data = [NSData data];

  hash = [data SHA1Hash];
  hashString = [GTMBase64 stringByEncodingData:hash];
  expectedHash = @"2jmj7l5rSw0yVb/vlWAYkK/YBwk=";
  STAssertEqualObjects(hashString, expectedHash, nil);

  // Some actual bytes.
  data = [@"Don't Hassle The Hoff" dataUsingEncoding:NSUTF8StringEncoding];
  hash = [data SHA1Hash];
  hashString = [GTMBase64 stringByEncodingData:hash];
  expectedHash = @"+WcDyvV4b/Vbj2+U9SEnJI/IAjw=";
  STAssertEqualObjects(hashString, expectedHash, nil);

}  // testBasics

@end  // NSData_HashTest

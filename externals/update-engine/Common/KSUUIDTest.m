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
#import "KSUUID.h"


@interface KSUUIDTest : SenTestCase
@end


@implementation KSUUIDTest

- (void)testBasics {
  // Make sure we get a reasonable looking string;
  NSString *uuid1 = [KSUUID uuidString];
  
  // Make sure there's character groupings of 8-4-4-4-12

  NSArray *chunks;
  chunks = [uuid1 componentsSeparatedByString:@"-"];
  STAssertEquals([chunks count], 5U, nil);

  STAssertEquals([[chunks objectAtIndex:0] length], 8U, nil);
  STAssertEquals([[chunks objectAtIndex:1] length], 4U, nil);
  STAssertEquals([[chunks objectAtIndex:2] length], 4U, nil);
  STAssertEquals([[chunks objectAtIndex:3] length], 4U, nil);
  STAssertEquals([[chunks objectAtIndex:4] length], 12U, nil);

  // Make sure we don't just keep getting the same string.
  NSString *uuid2 = [KSUUID uuidString];
  STAssertFalse([uuid1 isEqualToString:uuid2], nil);
}

@end

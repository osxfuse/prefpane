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
#import "KSActionPipe.h"
#import "KSAction.h"


@interface KSActionPipeTest : SenTestCase 
@end


@implementation KSActionPipeTest

- (void)testBasic {
  KSActionPipe *pipe = [KSActionPipe pipe];
  STAssertNotNil(pipe, nil);
  
  STAssertNil([pipe contents], nil);
  [pipe setContents:@"hi"];
  STAssertNotNil([pipe contents], nil);
  STAssertEqualObjects([pipe contents], @"hi", nil);
  
  pipe = [KSActionPipe pipeWithContents:@"foo"];
  STAssertNotNil([pipe contents], nil);
  STAssertEqualObjects([pipe contents], @"foo", nil);
  
  STAssertTrue([[pipe description] length] > 3, nil);
  
  // Test pipe bonding
  KSAction *a1 = [[[KSAction alloc] init] autorelease];
  STAssertNotNil(a1, nil);
  KSAction *a2 = [[[KSAction alloc] init] autorelease];
  STAssertNotNil(a2, nil);
  
  [pipe bondFrom:a1 to:a2];
  STAssertTrue([a1 outPipe] == pipe, nil);
  STAssertTrue([a2 inPipe] == pipe, nil);
  
  // Test pipe bonding using class method
  KSAction *a3 = [[[KSAction alloc] init] autorelease];
  STAssertNotNil(a1, nil);
  KSAction *a4 = [[[KSAction alloc] init] autorelease];
  STAssertNotNil(a2, nil);

  [KSActionPipe bondFrom:a3 to:a4];
  STAssertTrue([a3 outPipe] == [a4 inPipe], nil);
}

@end

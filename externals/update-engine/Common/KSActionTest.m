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
#import "KSAction.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"


@interface KSActionTest : SenTestCase
@end

// Notes about this unit test
// --------------------------
// KSAction is an abstract class, and there's currently nothing to isolate and
// test in this unit test. So, here we'll just test that we can instantiate it
// (yes, I know we're instantiating an "abstract" class, but at least it ensures
// that everything compiles and all the machinery works up to that point) and
// verify that we get a non-nil instance. If more functionality is added to the
// KSAction class in the future, the unit test is already setup for it.
//
// Also note that we *can* test how concrete KSAction instances interact with
// the KSActionProcessor, and we do that in the KSActionProcessorTest file.


@implementation KSActionTest

- (void)testBasic {
  KSAction *action = [[[KSAction alloc] init] autorelease];
  STAssertNotNil(action, nil);
  STAssertTrue([action isRunning] == NO, nil);
  STAssertNil([action processor], nil);
  [action setProcessor:[[[KSActionProcessor alloc] init] autorelease]];
  STAssertNotNil([action processor], nil);

  // The in/out pipes should never be nil.
  STAssertNotNil([action inPipe], nil);
  STAssertNotNil([action outPipe], nil);
  [action setInPipe:[KSActionPipe pipe]];
  [action setOutPipe:[KSActionPipe pipe]];
  STAssertNotNil([action inPipe], nil);
  STAssertNotNil([action outPipe], nil);
  [action setInPipe:nil];
  [action setOutPipe:nil];
  STAssertNotNil([action inPipe], nil);
  STAssertNotNil([action outPipe], nil);

  [action terminateAction];

  // Since KSAction itself is an "abstract" class, calling performAction:
  // on it would _GTMDevAssert and abort the test.
}

@end

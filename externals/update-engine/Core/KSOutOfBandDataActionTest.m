// Copyright 2010 Google Inc.
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
#import "KSActionConstants.h"
#import "KSActionPipe.h"
#import "KSMemoryTicketStore.h"
#import "KSOutOfBandDataAction.h"
#import "KSUpdateEngine.h"


@interface KSOutOfBandDataActionTest : SenTestCase {
  KSOutOfBandDataAction *oobAction_;

  // Set in the delegate if the delegate is called.
  NSDictionary *seenOOBData_;
  BOOL delegateCalled_;
}
@end


@implementation KSOutOfBandDataActionTest

- (void)setUp {
  // Set up the life support to be able to run the action.
  KSTicketStore *store = [[[KSMemoryTicketStore alloc] init] autorelease];
  KSUpdateEngine *engine = [KSUpdateEngine engineWithTicketStore:store
                                                        delegate:self];
  oobAction_ = [[KSOutOfBandDataAction actionWithEngine:engine] retain];
  KSActionPipe *inPipe = [KSActionPipe pipe];
  KSActionPipe *outPipe = [KSActionPipe pipe];
  [oobAction_ setInPipe:inPipe];
  [oobAction_ setOutPipe:outPipe];

  // Clean slate.
  seenOOBData_ = nil;
  delegateCalled_ = NO;
}

- (void)tearDown {
  [oobAction_ release];
  [seenOOBData_ release];
}

- (void)testCreation {
  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  KSOutOfBandDataAction *oobda =
    [KSOutOfBandDataAction actionWithEngine:engine];
  STAssertNotNil(oobda, nil);
}

- (void)testDelegateNotification {
  NSDictionary *oobData = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"snork", @"waffle", nil];
  NSArray *infos = [NSArray array];

  // Construct input with OOB data.
  NSDictionary *input =
    [NSDictionary dictionaryWithObjectsAndKeys:
                  infos, KSActionUpdateInfosKey,
                  oobData, KSActionOutOfBandDataKey,
                  nil];
  [[oobAction_ inPipe] setContents:input];

  [oobAction_ performAction];
  STAssertTrue(delegateCalled_, nil);
  STAssertEquals(seenOOBData_, oobData, nil);

  // Make sure the out pipe gets just the updateInfos.
  STAssertEquals([[oobAction_ outPipe] contents], infos, nil);
}

// Delegate method.
- (void)engine:(KSUpdateEngine *)engine hasOutOfBandData:(NSDictionary *)oob {
  seenOOBData_ = [oob retain];
  delegateCalled_ = YES;
}

@end

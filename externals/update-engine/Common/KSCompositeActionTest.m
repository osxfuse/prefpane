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
#import "KSCompositeAction.h"
#import "KSAction.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"


@interface KSCompositeActionTest : SenTestCase
@end


@interface SuccessAction : KSAction
@end
@implementation SuccessAction
- (void)performAction {
  [[self outPipe] setContents:@"success"];
  [[self processor] finishedProcessing:self successfully:YES];
}
@end


@interface FailedAction : KSAction
@end
@implementation FailedAction
- (void)performAction {
  [[self outPipe] setContents:@"failed"];
  [[self processor] finishedProcessing:self successfully:NO];
}
@end


@interface NullAction : KSAction
@end
@implementation NullAction
- (void)performAction {
  // Never tell the processor that we finished running so that we can test 
  // terminating an action.
}
@end


@implementation KSCompositeActionTest

- (void)testCreation {
  KSAction *action = nil;
  
  action = [[[KSCompositeAction alloc] init] autorelease];
  STAssertNil(action, nil);
  
  action = [KSCompositeAction actionWithActions:[NSArray arrayWithObject:@"hi"]];
  STAssertNotNil(action, nil);
  
  STAssertTrue([[action description] length] > 1, nil);
}

- (void)test1SuccessfulAction {
  NSArray *actions = [NSArray arrayWithObject:
                      [[[SuccessAction alloc] init] autorelease]];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];  
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);


  STAssertTrue([[composite completedActions] count] == 1, nil);
  STAssertTrue([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"success", nil);
}

- (void)test2SuccessfulActions {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 2, nil);
  STAssertTrue([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"success", nil);
}

- (void)test10SuccessfulActions {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 10, nil);
  STAssertTrue([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"success", nil);
}

- (void)test1FailureAction {
  NSArray *actions = [NSArray arrayWithObject:
                      [[[FailedAction alloc] init] autorelease]];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 0, nil);
  STAssertFalse([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"failed", nil);
}

- (void)test2FailureActions {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[FailedAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 0, nil);
  STAssertFalse([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"failed", nil);
}

- (void)test1Success1Failure {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[SuccessAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 1, nil);
  STAssertFalse([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"failed", nil);
}

- (void)test5Success5Failure {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 5, nil);
  STAssertFalse([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"failed", nil);
}

- (void)test9Success1Failure {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[FailedAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 9, nil);
  STAssertFalse([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"failed", nil);
}

- (void)test1Failure9Successes {
  NSArray *actions = [NSArray arrayWithObjects:
                      [[[FailedAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      [[[SuccessAction alloc] init] autorelease],
                      nil];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 0, nil);
  STAssertFalse([composite completedSuccessfully], nil);
  STAssertEqualObjects([[composite outPipe] contents], @"failed", nil);
}

- (void)testNullAction {
  NSArray *actions = [NSArray arrayWithObject:
                      [[[NullAction alloc] init] autorelease]];
  
  KSCompositeAction *composite = [KSCompositeAction actionWithActions:actions];
  STAssertNotNil(composite, nil);
  
  STAssertEqualObjects(actions, [composite actions], nil);
  STAssertNil([composite completedActions], nil);
  STAssertFalse([composite isRunning], nil);
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:composite];
  
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  [ap stopProcessing];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  STAssertTrue([[composite completedActions] count] == 0, nil);
  STAssertFalse([composite completedSuccessfully], nil);
}

@end

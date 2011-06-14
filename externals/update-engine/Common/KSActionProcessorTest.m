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
#import "KSActionProcessor.h"
#import "KSAction.h"
#import "GTMLogger.h"


@interface KSActionProcessorTest : SenTestCase
@end


// Unit test notes
// ---------------
// We're testing the KSActionProcessor here. We test it by creating two
// KSAction subclasses: one that performs an asynchronous action and one that
// performs an action synchronously. Each of these classes will create more
// actions that will be added to the KSActionProcessor's queue while the action
// is running.
//
// The unit tests will make sure that all the actions get executed in the right
// order, and that all the delegate callbacks happen correctly.


// Simple do-nothing action, for testing.
@interface NOPAction : KSAction
@end

@implementation NOPAction

- (void)performAction {
  [[self processor] finishedProcessing:self successfully:YES]; 
}

@end  // NOPAction


// A sample KSAction subclass that runs an asynchronous action. This action will
// also add other TestAsyncAction instances to the action queue (up to 10).
@interface TestAsyncAction : KSAction {
  int num_;
}
@end

@implementation TestAsyncAction

- (id)initWithNum:(int)num {
  if ((self = [super init])) {
    num_ = num;
  }
  return self;
}

- (void)performAction {
  GTMLoggerInfo(@"num = %d, processor = %@", num_, [self processor]);
  [NSTimer scheduledTimerWithTimeInterval:0.1
                                   target:self
                                 selector:@selector(fire:)
                                 userInfo:nil
                                  repeats:NO];
}

- (void)fire:(NSTimer *)timer {
  GTMLoggerInfo(@"num = %d", num_);
  if (num_ < 10) {
    TestAsyncAction *newAction = [[[TestAsyncAction alloc] initWithNum:++num_] autorelease];
    [[self processor] enqueueAction:newAction];
  }
  [[self processor] finishedProcessing:self successfully:YES];
}

@end  // TestAsyncAction


// Test action for sending progress callbacks
@interface ProgressAction : KSAction {
  int totalCalls_;
  int callsMade_;
  NSTimeInterval interval_;
  float progress_;
  NSTimer *timer_;
}
- (id)initWithCalls:(int)interval;
@end

@implementation ProgressAction

- (id)initWithCalls:(int)calls {
  if ((self = [super init])) {
    totalCalls_ = calls;
    interval_ = (float)1/calls;
  }
  return self;
}

- (void)performAction {
  GTMLoggerInfo(@"interval_ = %f, processor = %@", interval_, [self processor]);
  timer_ = [[NSTimer scheduledTimerWithTimeInterval:interval_
                                             target:self
                                           selector:@selector(fire:)
                                           userInfo:nil
                                            repeats:YES] retain];
}

- (void)fire:(NSTimer *)timer {
  ++callsMade_;
  progress_ += interval_;
  GTMLoggerInfo(@"TEST: progress_ = %f, interval = %f", progress_, interval_);
  [[self processor] runningAction:self progress:progress_];
  
  if (callsMade_ >= totalCalls_) {
    [timer_ invalidate];
    [timer_ release];
    timer_ = nil;
    [[self processor] finishedProcessing:self successfully:YES];
  }
}

@end  // ProgressAction


// A sample KSAction that runs an action synchronously. This action will also
// add other KSActions to the action queue (up to 10). The type of action added
// is configurable through the toggle parameter. If |toggle| is YES, then the
// actions added will alternate between TestAction and TestAsyncAction.
@interface TestAction : KSAction {
  int num_;
  BOOL toggle_;
}
@end

@implementation TestAction

- (id)initWithNum:(int)num toggle:(BOOL)toggle {
  if ((self = [super init])) {
    num_ = num;
    toggle_ = toggle;
  }
  return self;
}

- (void)performAction {
  GTMLoggerInfo(@"num = %d, processor = %@", num_, [self processor]);
  if (num_ < 10) {
    TestAction *newAction = nil;

    if (toggle_ && (num_ % 2) == 0)
      newAction = [[[TestAsyncAction alloc] initWithNum:++num_] autorelease];
    else
      newAction = [[[TestAction alloc] initWithNum:++num_ toggle:NO] autorelease];

    [[self processor] enqueueAction:newAction];
  }
  [[self processor] finishedProcessing:self successfully:YES];
}

@end  // TestAction


// This is a KSActionProcessor delegate. It simply records the number of times
// a delegate method is called, and the order in which they're called. This
// is used to verify that delegate methods happend correctly.
@interface MethodCounter : NSObject {
  NSMutableDictionary *methodCalls_;
  NSMutableArray *callOrder_;
}
@end

@implementation MethodCounter

+ (id)counter {
  return [[[self alloc] init] autorelease];
}

- (id)init {
  if ((self = [super init])) {
    methodCalls_ = [[NSMutableDictionary alloc] init];
    callOrder_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [methodCalls_ release];
  [callOrder_ release];
  [super dealloc];
}

- (NSDictionary *)methodCalls {
  return methodCalls_;
}

- (NSArray *)callOrder {
  return callOrder_;
}

// Sent when processing is started.
- (void)processingStarted:(KSActionProcessor *)processor {
  NSString *key = NSStringFromSelector(_cmd);
  NSNumber *count = [methodCalls_ objectForKey:key];
  [methodCalls_ setObject:[NSNumber numberWithInt:(1 + [count intValue])]
                   forKey:key];
  [callOrder_ addObject:key];
  GTMLoggerInfo(@"%@", processor);
}

// Sent when the action queue is empty.
- (void)processingDone:(KSActionProcessor *)processor {
  NSString *key = NSStringFromSelector(_cmd);
  NSNumber *count = [methodCalls_ objectForKey:key];
  [methodCalls_ setObject:[NSNumber numberWithInt:(1 + [count intValue])]
                   forKey:key];
  [callOrder_ addObject:key];
  GTMLoggerInfo(@"%@", processor);
}

// Sent when processing is stopped by via the -stopProcessing message. This
// does not imply that the action queue is empty.
- (void)processingStopped:(KSActionProcessor *)processor {
  NSString *key = NSStringFromSelector(_cmd);
  NSNumber *count = [methodCalls_ objectForKey:key];
  [methodCalls_ setObject:[NSNumber numberWithInt:(1 + [count intValue])]
                   forKey:key];
  [callOrder_ addObject:key];
  GTMLoggerInfo(@"%@", processor);
}

// Called after an action has been enqueued by the KSActionProcessor.
- (void)processor:(KSActionProcessor *)processor
   enqueuedAction:(KSAction *)action {
  NSString *key = NSStringFromSelector(_cmd);
  NSNumber *count = [methodCalls_ objectForKey:key];
  [methodCalls_ setObject:[NSNumber numberWithInt:(1 + [count intValue])]
                   forKey:key];
  [callOrder_ addObject:key];
  GTMLoggerInfo(@"%@ %@", processor, action);
}

// Called right before the KSActionProcessor starts the KSAction by sending it
// the -performAction: message.
- (void)processor:(KSActionProcessor *)processor
   startingAction:(KSAction *)action {
  NSString *key = NSStringFromSelector(_cmd);
  NSNumber *count = [methodCalls_ objectForKey:key];
  [methodCalls_ setObject:[NSNumber numberWithInt:(1 + [count intValue])]
                   forKey:key];
  [callOrder_ addObject:key];
  GTMLoggerInfo(@"%@ %@", processor, action);
}

// Called once the KSAction informs the KSActionProcessor that the action has
// finished.
- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  NSString *key = NSStringFromSelector(_cmd);
  NSNumber *count = [methodCalls_ objectForKey:key];
  [methodCalls_ setObject:[NSNumber numberWithInt:(1 + [count intValue])]
                   forKey:key];
  [callOrder_ addObject:key];
  GTMLoggerInfo(@"%@ %@", processor, action);
}

@end  // MethodCounter


@interface ProgressRecorder : NSObject {
  NSMutableArray *calls_;
}
- (NSArray *)calls;
@end

@implementation ProgressRecorder

- (id)init {
  if ((self = [super init])) {
    calls_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [calls_ release];
  [super dealloc];
}

- (NSArray *)calls {
  return calls_;
}

- (void)processor:(KSActionProcessor *)processor
    runningAction:(KSAction *)action
         progress:(float)progress {
  NSString *call = [NSString stringWithFormat:@"action:%.02f,processor:%.02f",
                    progress, [processor progress]];
  [calls_ addObject:call];
}

@end


@interface KSActionProcessor (InternalPrivateMethods)
- (void)updateProgressWithFraction:(float)fraction;
@end

//
// Begin unit test code
//

@implementation KSActionProcessorTest

- (void)testBasic {
  KSActionProcessor *ap = nil;

  ap = [[[KSActionProcessor alloc] initWithDelegate:nil] autorelease];
  STAssertNotNil(ap, nil);

  ap = [[[KSActionProcessor alloc] initWithDelegate:@"blah"] autorelease];
  STAssertNotNil(ap, nil);

  ap = [[[KSActionProcessor alloc] init] autorelease];
  STAssertNotNil(ap, nil);

  STAssertTrue([[ap actions] count] == 0, nil);
  [ap enqueueAction:nil];
  STAssertTrue([[ap actions] count] == 0, nil);

  [ap enqueueAction:[[[KSAction alloc] init] autorelease]];
  [ap enqueueAction:[[[KSAction alloc] init] autorelease]];
  [ap enqueueAction:[[[KSAction alloc] init] autorelease]];

  STAssertTrue([[ap actions] count] == 3, nil);
  STAssertTrue([ap actionsCompleted] == 0, nil);

  STAssertNil([ap delegate], nil);
  [ap setDelegate:@"blah"];
  STAssertNotNil([ap delegate], nil);

  STAssertTrue([[ap description] length] > 1, nil);
}

- (void)verifyMethodCounter:(MethodCounter *)counter {
  //
  // Make sure each delegate method was called the correct number of times
  //

  NSDictionary *calls = [counter methodCalls];
  STAssertNotNil(calls, nil);
  // There are 7 delegate methods total, but MethodCounter only counts 6 of
  // them. The one that's not counted is processor:runningAction:progress:,
  // because that method can be called a number of times 
  STAssertTrue([calls count] == 6, nil);

  STAssertEqualObjects([calls objectForKey:@"processingStarted:"],
                       [NSNumber numberWithInt:1], nil);

  STAssertEqualObjects([calls objectForKey:@"processingDone:"],
                       [NSNumber numberWithInt:1], nil);

  STAssertEqualObjects([calls objectForKey:@"processingStopped:"],
                       [NSNumber numberWithInt:1], nil);

  STAssertEqualObjects([calls objectForKey:@"processor:enqueuedAction:"],
                       [NSNumber numberWithInt:10], nil);

  STAssertEqualObjects([calls objectForKey:@"processor:startingAction:"],
                       [NSNumber numberWithInt:10], nil);

  STAssertEqualObjects([calls objectForKey:@"processor:finishedAction:successfully:"],
                       [NSNumber numberWithInt:10], nil);

  //
  // Make sure the methods were called in the correct order.
  //

  NSArray *order = [counter callOrder];
  STAssertNotNil(order, nil);
  STAssertTrue([order count] == 33, nil);  // 33 calls total

  NSArray *correctOrder = [NSArray arrayWithObjects:
                           @"processor:enqueuedAction:",
                           @"processingStarted:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:enqueuedAction:",
                           @"processor:finishedAction:successfully:",
                           @"processor:startingAction:",
                           @"processor:finishedAction:successfully:",
                           @"processingDone:",
                           @"processingStopped:",
                           nil];

  STAssertTrue([order count] == [correctOrder count], nil);
  STAssertEqualObjects(order, correctOrder, nil);

  // Useful for debugging
  // GTMLoggerInfo(@"methodCalls = %@", calls);
  // GTMLoggerInfo(@"callOrder = %@", [counter callOrder]);
}

// The guts of a sync test but allow the caller to specify the number
// of times [ap startProcessing] is called.
- (void)commonTestSynchronousWithStarts:(int)starts {
  // Create an action processor delegate that counts the delegate calls
  MethodCounter *counter = [MethodCounter counter];
  STAssertNotNil(counter, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:counter] autorelease];
  STAssertNotNil(ap, nil);

  // Create some simple action to start the ball rolling. This action will
  // create other actions that will be appended to the action processor queue.
  // A total of 10 actions should be used overall (in this test).
  KSAction *action = [[[TestAction alloc] initWithNum:1 toggle:NO] autorelease];
  STAssertNotNil(action, nil);
  STAssertTrue([ap actionsCompleted] == 0, nil);

  // Add our one action to kick things off, then start processing the queue
  [ap enqueueAction:action];

  // INTERNAL KNOWLEDGE:
  // startProcessing: calls processHead: which asserts if the
  // currentAction_ isn't nil.  The currentAction_ becomes non-nil as
  // a result of a valid call to processHead:.
  // Thus, if >1 of these calls don't throw an assert, we're fine.
  for (int i = 0; i < starts; i++)
    [ap startProcessing];

  // Since this is the synchronous test, all actions will be done by this point,
  // so we can verify that all the delegate methods worked correctly.
  // Only call verifyMethodCounter on the "normal" case, since the
  // trap mechanism doesn't understand excessive starts.
  if (starts == 1)
    [self verifyMethodCounter:counter];

  STAssertTrue([ap actionsCompleted] > 1, nil);
}

- (void)testSynchronous {
  [self commonTestSynchronousWithStarts:1];
}

- (void)testExcessiveStartProcessing {
  [self commonTestSynchronousWithStarts:8];
}

- (void)testAsynchronous {
  MethodCounter *counter = [MethodCounter counter];
  STAssertNotNil(counter, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:counter] autorelease];
  STAssertNotNil(ap, nil);

  // Create an action that does its stuff asynchronously.
  KSAction *action = [[[TestAsyncAction alloc] initWithNum:1] autorelease];
  STAssertNotNil(action, nil);

  // Add our one action to kick things off, then start processing the queue
  [ap enqueueAction:action];
  [ap startProcessing];

  // Since we're testing asynchronous actions, we need to spin the runloop for
  // a bit to make sure all of our actions complete. Each action uses a 0.1
  // second timer, so spinning for 2 seconds should be more than enough time
  // for everything to complete.
  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:2];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];

  [self verifyMethodCounter:counter];
}

- (void)testBoth {
  MethodCounter *counter = [MethodCounter counter];
  STAssertNotNil(counter, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:counter] autorelease];
  STAssertNotNil(ap, nil);

  // Create an action that will create sync and async actions in the same Q
  KSAction *action = [[[TestAction alloc] initWithNum:1 toggle:YES] autorelease];
  STAssertNotNil(action, nil);

  // Add our one action to kick things off, then start processing the queue
  [ap enqueueAction:action];
  STAssertTrue([ap actionsCompleted] == 0, nil);
  [ap startProcessing];

  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:1];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];

  [self verifyMethodCounter:counter];
  STAssertTrue([ap actionsCompleted] > 3, nil);
}

- (void)testUpdateProgress {
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:nil] autorelease];
  KSAction *nop = [[[NOPAction alloc] init] autorelease];
  [ap enqueueAction:nop];
  STAssertNotNil(ap, nil);
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  
  [ap updateProgressWithFraction:0.1];
  STAssertEqualsWithAccuracy([ap progress], 0.1f, 0.01, nil);
  
  [ap updateProgressWithFraction:0.2];
  STAssertEqualsWithAccuracy([ap progress], 0.2f, 0.01, nil);

  [ap updateProgressWithFraction:0.3];
  STAssertEqualsWithAccuracy([ap progress], 0.3f, 0.01, nil);
  
  [ap updateProgressWithFraction:1.0];
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  [ap updateProgressWithFraction:0.0];
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
}

- (void)testProgressSingleAction {
  ProgressRecorder *recorder = [[[ProgressRecorder alloc] init] autorelease];
  STAssertNotNil(recorder, nil);
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:recorder] autorelease];
  STAssertNotNil(ap, nil);
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  
  KSAction *action = [[[ProgressAction alloc] initWithCalls:10] autorelease];
  STAssertNotNil(action, nil);
  
  [ap enqueueAction:action];
  STAssertTrue([ap actionsCompleted] == 0, nil);
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);

  [ap startProcessing];
  
  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:1];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];
  
  STAssertFalse([ap isProcessing], nil);
  STAssertEquals([ap actionsCompleted], 1, nil);
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  NSArray *progressCalls = [recorder calls];
  STAssertTrue([progressCalls count] == 10, nil);
  
  NSArray *expectedCalls = [NSArray arrayWithObjects:
                            @"action:0.10,processor:0.10",
                            @"action:0.20,processor:0.20",
                            @"action:0.30,processor:0.30",
                            @"action:0.40,processor:0.40",
                            @"action:0.50,processor:0.50",
                            @"action:0.60,processor:0.60",
                            @"action:0.70,processor:0.70",
                            @"action:0.80,processor:0.80",
                            @"action:0.90,processor:0.90",
                            @"action:1.00,processor:1.00",
                            nil];
  STAssertEqualObjects(progressCalls, expectedCalls, nil);
}

- (void)testProgressMultipleActions {
  ProgressRecorder *recorder = [[[ProgressRecorder alloc] init] autorelease];
  STAssertNotNil(recorder, nil);
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:recorder] autorelease];
  STAssertNotNil(ap, nil);
  
  KSAction *action1 = [[[ProgressAction alloc] initWithCalls:10] autorelease];
  STAssertNotNil(action1, nil);
  
  KSAction *action2 = [[[ProgressAction alloc] initWithCalls:10] autorelease];
  STAssertNotNil(action2, nil);
  
  [ap enqueueAction:action1];
  [ap enqueueAction:action2];
  STAssertTrue([ap actionsCompleted] == 0, nil);
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);

  [ap startProcessing];
  
  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:2.2];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];
  
  STAssertFalse([ap isProcessing], nil);
  STAssertEquals([ap actionsCompleted], 2, nil);
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  NSArray *progressCalls = [recorder calls];
  STAssertTrue([progressCalls count] == 20, nil);
  
  NSArray *expectedCalls = [NSArray arrayWithObjects:
                            @"action:0.10,processor:0.05",
                            @"action:0.20,processor:0.10",
                            @"action:0.30,processor:0.15",
                            @"action:0.40,processor:0.20",
                            @"action:0.50,processor:0.25",
                            @"action:0.60,processor:0.30",
                            @"action:0.70,processor:0.35",
                            @"action:0.80,processor:0.40",
                            @"action:0.90,processor:0.45",
                            @"action:1.00,processor:0.50",
                            @"action:0.10,processor:0.55",
                            @"action:0.20,processor:0.60",
                            @"action:0.30,processor:0.65",
                            @"action:0.40,processor:0.70",
                            @"action:0.50,processor:0.75",
                            @"action:0.60,processor:0.80",
                            @"action:0.70,processor:0.85",
                            @"action:0.80,processor:0.90",
                            @"action:0.90,processor:0.95",
                            @"action:1.00,processor:1.00",
                            nil];
  STAssertEqualObjects(progressCalls, expectedCalls, nil);
}

- (void)testProgressMixedActions {
  ProgressRecorder *recorder = [[[ProgressRecorder alloc] init] autorelease];
  STAssertNotNil(recorder, nil);
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] initWithDelegate:recorder] autorelease];
  STAssertNotNil(ap, nil);
  
  KSAction *action1 = [[[ProgressAction alloc] initWithCalls:10] autorelease];
  STAssertNotNil(action1, nil);
  
  KSAction *action2 = [[[NOPAction alloc] init] autorelease];
  STAssertNotNil(action2, nil);
  
  [ap enqueueAction:action1];
  [ap enqueueAction:action2];
  STAssertTrue([ap actionsCompleted] == 0, nil);
  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  
  [ap startProcessing];
  
  NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:2.2];
  [[NSRunLoop currentRunLoop] runUntilDate:quick];
  
  STAssertFalse([ap isProcessing], nil);
  STAssertEquals([ap actionsCompleted], 2, nil);
  
  // Verify that the progress now is 1.0
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);
  
  NSArray *progressCalls = [recorder calls];
  STAssertTrue([progressCalls count] == 10, nil);
  
  NSArray *expectedCalls = [NSArray arrayWithObjects:
                            @"action:0.10,processor:0.05",
                            @"action:0.20,processor:0.10",
                            @"action:0.30,processor:0.15",
                            @"action:0.40,processor:0.20",
                            @"action:0.50,processor:0.25",
                            @"action:0.60,processor:0.30",
                            @"action:0.70,processor:0.35",
                            @"action:0.80,processor:0.40",
                            @"action:0.90,processor:0.45",
                            @"action:1.00,processor:0.50",
                            nil];
  STAssertEqualObjects(progressCalls, expectedCalls, nil);
}

@end

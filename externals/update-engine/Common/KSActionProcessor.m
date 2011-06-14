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

#import "KSActionProcessor.h"
#import "KSAction.h"
#import "GTMDefines.h"
#import "GTMLogger.h"

@interface KSActionProcessor (PrivateMethods)
- (void)updateProgressWithFraction:(float)fraction;
- (void)setCurrentAction:(KSAction *)action;
- (void)processHead;
@end


@implementation KSActionProcessor

- (id)init {
  return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id)delegate {
  if ((self = [super init])) {
    delegate_ = delegate;
    actionQ_ = [[NSMutableArray alloc] init];
    _GTMDevAssert(actionQ_ != nil, @"actionQ_ should never be nil");
  }
  return self;
}

- (void)dealloc {
  [self stopProcessing];  // This will release currentAction_
  [actionQ_ release];
  [super dealloc];
}

- (id)delegate {
  return delegate_;
}

- (void)setDelegate:(id)delegate {
  delegate_ = delegate;
}

- (void)enqueueAction:(KSAction *)action {
  _GTMDevAssert(actionQ_ != nil, @"actionQ_ should never be nil");
  if (action == nil) return;
  @synchronized (self) {
    [actionQ_ addObject:action];
    [action setProcessor:self];
    if ([delegate_ respondsToSelector:@selector(processor:enqueuedAction:)])
      [delegate_ processor:self enqueuedAction:action];
  }
}

- (NSArray *)actions {
  _GTMDevAssert(actionQ_ != nil, @"actionQ_ should never be nil");
  // We give the caller a non-mutable snapshot of the current actions so that
  // they can't touch our privates (ewww, that'd be bad).
  return [[actionQ_ copy] autorelease];
}

- (void)startProcessing {
  @synchronized (self) {
    if (isProcessing_)
      return;

    isProcessing_ = YES;

    if ([delegate_ respondsToSelector:@selector(processingStarted:)])
      [delegate_ processingStarted:self];

    [self processHead];
  }
}

- (void)stopProcessing {
  @synchronized (self) {
    isProcessing_ = NO;

    // Stop the current action then set it to nil (which will release it)
    [currentAction_ terminateAction];
    [currentAction_ setProcessor:nil];
    [self setCurrentAction:nil];

    if ([delegate_ respondsToSelector:@selector(processingStopped:)])
      [delegate_ processingStopped:self];
  }
}

- (BOOL)isProcessing {
  return isProcessing_;
}

- (float)progress {
  return progress_;
}

- (KSAction *)currentAction {
  return [[currentAction_ retain] autorelease];
}

- (int)actionsCompleted {
  return actionsCompleted_;
}

- (NSString *)description {
  return [NSString stringWithFormat:
          @"<%@:%p isProcessing=%d actions=%d current=%@>", [self class],
          self, isProcessing_, [actionQ_ count], [currentAction_ class]];
}

@end  // KSActionProcessor


@implementation KSActionProcessor (KSActionProcessorCallbacks)

- (void)runningAction:(KSAction *)action progress:(float)progress {
  [self updateProgressWithFraction:progress];
  SEL sel = @selector(processor:runningAction:progress:);
  if ([delegate_ respondsToSelector:sel])
    [delegate_ processor:self runningAction:action progress:progress];
}

- (void)finishedProcessing:(KSAction *)action successfully:(BOOL)wasOK {
  @synchronized (self) {
    if (action != currentAction_) {
      // COV_NF_START
      GTMLoggerError(@"finished processing %@, which was not the current action"
                     @" (%@)", action, currentAction_);
      return;
      // COV_NF_END
    }
        
    [self updateProgressWithFraction:1.0f];
    
    SEL sel = @selector(processor:finishedAction:successfully:);
    if ([delegate_ respondsToSelector:sel])
      [delegate_ processor:self finishedAction:action successfully:wasOK];

    // Get rid of our current action since it's finished
    [currentAction_ setProcessor:nil];
    [self setCurrentAction:nil];
    
    actionsCompleted_++;

    // If we're still supposed to be processing, process the next action
    if (isProcessing_)
      [self processHead];
  }
}

@end  // KSActionProcessorCallbacks


@implementation KSActionProcessor (PrivateMethods)

- (void)updateProgressWithFraction:(float)fraction {
  NSInteger totalActions = [actionQ_ count] + actionsCompleted_;
  // Count the currently running action, and don't let totalActions == 0
  if (isProcessing_ || totalActions == 0) totalActions += 1;
  _GTMDevAssert(totalActions != 0, @"totalActions must not be 0");
  float unit = (float)1 / totalActions;
  @synchronized (self) {
    progress_ = (unit * actionsCompleted_) + (unit * fraction);
    // ensures 0.0 < progress_ < 1.0
    progress_ = (progress_ > 1.0f) ? 1.0f : progress_;
    progress_ = (progress_ < 0.0f) ? 0.0f : progress_;
  }
}

- (void)setCurrentAction:(KSAction *)action {
  [currentAction_ autorelease];
  currentAction_ = [action retain];
}

- (void)processHead {
  _GTMDevAssert(actionQ_ != nil, @"actionQ_ should never be nil");

  @synchronized (self) {
    _GTMDevAssert(currentAction_ == nil,
                  @"currentAction_ (%@) must be nil before "
                  @"processing a new action", currentAction_);

    if ([actionQ_ count] > 0) {
      // Get the first action and assign it to currentAction_, make sure the
      // action is not already running, then remove it from the queue.
      KSAction *action = [actionQ_ objectAtIndex:0];

      // Make sure the action we're about to run isn't already running. This
      // would be illegal, so we'll log and scream if it happens.
      if ([action isRunning]) {
        // COV_NF_START
        [self stopProcessing];
        _GTMDevAssert(NO, @"%@ can't run %@ because it's already running!",
                      self, action);
        return;
        // COV_NF_END
      }

      [self setCurrentAction:action];
      [actionQ_ removeObjectAtIndex:0];

      if ([delegate_ respondsToSelector:@selector(processor:startingAction:)])
        [delegate_ processor:self startingAction:action];

      // Start the action
      [action performAction];
    } else {
      isProcessing_ = NO;
      // Tell the delegate that we're done processing
      if ([delegate_ respondsToSelector:@selector(processingDone:)])
        [delegate_ processingDone:self];

      [self stopProcessing];
    }
  }
}

@end  // PrivateMethods

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

#import "KSCompositeAction.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"
#import "GTMDefines.h"
#import "GTMLogger.h"


@implementation KSCompositeAction

+ (id)actionWithActions:(NSArray *)actions {
  return [[[self alloc] initWithActions:actions] autorelease];
}

- (id)init {
  return [self initWithActions:nil];
}

- (id)initWithActions:(NSArray *)actions {
  if ((self = [super init])) {
    actions_ = [actions copy];
    subProcessor_ = [[KSActionProcessor alloc] initWithDelegate:self];
    completedActions_ = [[NSMutableArray alloc] init];
        
    if ([actions_ count] == 0) {
      GTMLoggerDebug(@"can't create a composite action with no actions");
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [actions_ release];
  [subProcessor_ setDelegate:nil];
  [subProcessor_ release];
  [completedActions_ release];
  [super dealloc];
}

- (NSArray *)actions {
  return actions_;
}

- (NSArray *)completedActions {
  // If the array is empty, return nil instead
  return [completedActions_ count] > 0 ? completedActions_ : nil;
}

- (BOOL)completedSuccessfully {
  return [actions_ isEqualToArray:completedActions_];
}

// All we do here is add all of the actions in |actions_| to our subProcessor_,
// then tell it to start processing.
- (void)performAction {
  _GTMDevAssert(subProcessor_ != nil, @"subProcessor must not be nil");
  
  KSAction *action = nil;
  NSEnumerator *actionEnumerator = [actions_ objectEnumerator];
  while ((action = [actionEnumerator nextObject])) {
    [subProcessor_ enqueueAction:action];
  }
  
  [subProcessor_ startProcessing];
}

- (void)terminateAction {
  [subProcessor_ stopProcessing];
  [[self processor] finishedProcessing:self successfully:NO];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p actions=%@>",
          [self class], self, [self actions]];
}


//
// KSActionProcessor delegate methods.
// These callbacks will come from our |subProcessor_|
//

// Reports the progress of this composite action as the progress of the
// subprocessor.
- (void)processor:(KSActionProcessor *)processor
    runningAction:(KSAction *)action
         progress:(float)progress {
  [[self processor] runningAction:self progress:[subProcessor_ progress]];
}

// Our subProcessor_ will call this method everytime one of its actions
// finishes. We watch these messages and record actions that complete 
// successfully, and if any do fail, we stop all processing and inform the 
// action processor that we (|self|) are running on that we have failed.
- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  [[self processor] runningAction:self progress:[subProcessor_ progress]];
  // Make our outPipe contain the output of the last action. So, we'll just keep
  // replacing our outPipe contents with each action's outPipe contents as they
  // finish. Eventually we'll contain the output of the "last" one.
  [[self outPipe] setContents:[[action outPipe] contents]];
  if (wasOK) {
    [completedActions_ addObject:action];
  } else {
    GTMLoggerInfo(@"Composite sub-action failed %@", action);
    // If some (any) action fails, then we abort the whole thing
    [subProcessor_ stopProcessing];
    [[self processor] finishedProcessing:self successfully:NO];
  }
}

// When our subProcessor is finished, then we are done ourselves.
- (void)processingDone:(KSActionProcessor *)processor {
  [[self processor] finishedProcessing:self successfully:YES];
}

@end

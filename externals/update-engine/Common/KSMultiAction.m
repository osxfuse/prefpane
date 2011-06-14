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

#import "KSMultiAction.h"
#import "KSActionProcessor.h"


@implementation KSMultiAction

- (id)init {
  if ((self = [super init])) {
    subProcessor_ = [[KSActionProcessor alloc] initWithDelegate:self];
  }
  return self;
}

- (void)dealloc {
  [subProcessor_ setDelegate:nil];
  [subProcessor_ release];
  [super dealloc];
}

- (void)terminateAction {
  [subProcessor_ stopProcessing];
}

- (int)subActionsProcessed {
  return subActionsProcessed_;
}

//
// KSActionProcessor delegate methods.
// These callbacks will come from our |subProcessor_|
//

- (void)processingStarted:(KSActionProcessor *)processor {
  // Count the number of subactions that we're going to process
  subActionsProcessed_ = [[processor actions] count];
}

// When our subProcessor is finished, then we are done ourselves.
- (void)processingDone:(KSActionProcessor *)processor {
  [[self processor] finishedProcessing:self successfully:YES];
}

@end


@implementation KSMultiAction (ProtectedMethods)

- (KSActionProcessor *)subProcessor {
  return subProcessor_;
}

@end

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

#import "KSAction.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"
#import "GTMDefines.h"
#import "GTMLogger.h"


@implementation KSAction

- (id)init {
  if ((self = [super init])) {
    [self setInPipe:nil];
    [self setOutPipe:nil];
  }
  return self;
}

- (void)dealloc {
  [processor_ release];
  [inpipe_ release];
  [outpipe_ release];
  [super dealloc];
}

- (KSActionProcessor *)processor {
  return [[processor_ retain] autorelease];
}

- (void)setProcessor:(KSActionProcessor *)processor {
  [processor_ autorelease];
  processor_ = [processor retain];
}

- (KSActionPipe *)inPipe {
  return [[inpipe_ retain] autorelease];
}

- (void)setInPipe:(KSActionPipe *)inpipe {
  [inpipe_ autorelease];
  inpipe_ = [inpipe retain];
  if (inpipe_ == nil)  // Never let inpipe be nil
    inpipe_ = [[KSActionPipe alloc] init];
}

- (KSActionPipe *)outPipe {
  return [[outpipe_ retain] autorelease];
}

- (void)setOutPipe:(KSActionPipe *)outpipe {
  [outpipe_ autorelease];
  outpipe_ = [outpipe retain];
  if (outpipe_ == nil)  // Never let outpipe be nil
    outpipe_ = [[KSActionPipe alloc] init];
}

- (BOOL)isRunning {
  return [[self processor] currentAction] == self;
}

// COV_NF_START
- (void)performAction {
  // Subclasses must override this method, otherwise their actions will be
  // useless.

  // If this method is not overridden, we'll _GTMDevAssert so that debug builds
  // break, but in Release builds we'll just log and tell the processor that
  // we're done so it doesn't hang.

  _GTMDevAssert(NO, @"-performAction: method not overridden");
  [processor_ finishedProcessing:self successfully:NO];
}
// COV_NF_END

- (void)terminateAction {
  // Do nothing. Subclasses may optionally override this method if they need to
  // do special cleanup when their action is being terminated.
}

@end

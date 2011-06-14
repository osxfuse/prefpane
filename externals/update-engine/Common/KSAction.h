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

#import <Foundation/Foundation.h>

@class KSActionProcessor, KSActionPipe;

// KSAction (Abstract)
//
// Abstract class that encapsulates a unit of work--an Action--to be performed.
// Examples of possible KSAction subclasses might be a "KSDownloadAction" or a
// "KSInstallAction", that each do the obvious thing that their name implies.
// Concrete KSAction instances are run by adding them to a KSActionProcessor's
// queue, then starting the KSActionProcessor. KSAction instances may perform
// their task synchronously or asynchronously. The only requirement is that they
// must tell their owning KSActionProcessor when they are finished by sending
// the KSActionProcessor a -finishedProcessing:successfully: message.
//
// When a KSAction is added to a KSActionProcessor, the KSActionProcessor will
// call -setProcessor: on the KSAction to indicate that the action is "owned" by
// the KSActionProcessor. Note that this happens when the action is enqueued,
// which may be significantly before the action is told to run. Also note that
// the by the time the action is told to run via the -performAction message, the
// -processor method is guaranteed to return a valid KSActionProcessor.
//
// Input-Output:
//
// Every KSAction has one KSActionPipe for input and one for output. These pipes
// are always present and are never nil. However, they can be replaced, and
// reset at any time. Action pipes are one way for actions to communicate with
// one another. One action may store its output in a KSActionPipe, and another
// action may use that same pipe for its input; thus connecting the two actions.
//
// KSActionPipes should be viewed as filling the same role as typical pipes on
// a Unix command line: connecting the output of one job to the input of
// another. This is true even though KSActionPipes are at a higher-level (an
// "object" level) than the stream-of-bytes level of typical Unix pipe(2)s.
//
// Subclassing:
//
// KSAction subclasses may be created and configured as necessary to enable them
// to perform their action. They should not actually perform their action until
// they are sent the -performAction message from a KSActionProcessor. If the
// action runs asynchronously, it should also implement the -terminateAction
// method, which should stop the action and only return once the action has been
// terminated. Subclasses will typically only need to override two methods:
// -performAction, and possibly, -terminateAction. The KSAction implementation
// of all other methods should be sufficient for nearly all KSAction subclasses.
//
// The lifecycle of a KSAction looks like the following:
//
//   1. KSAction is created like normal (e.g., alloc/init)
//   2. KSAction is added to a KSActionProcessor, at which point the KSAction
//      is sent a -setProcessor: message.
//   3. Eventually, the action is sent the -performAction message indicating
//      that the action should do its work
//   4. The action may or may not be sent a -terminateAction message indicating
//      that all work it is doing should be immediately stopped
//   5. Once the action completes successfully or otherwise, it is sent a
//      -setProcessor:nil message to indicate that it was removed from the
//      KSActionProcessor.
@interface KSAction : NSObject {
 @private
  KSActionProcessor *processor_;
  KSActionPipe *inpipe_;
  KSActionPipe *outpipe_;
}

// Returns the KSActionProcessor instance that owns this KSAction.
- (KSActionProcessor *)processor;

// Sets the KSActionProcessor that owns this KSAction. Note that a KSAction may
// only be in one KSActionProcessor at a time.
- (void)setProcessor:(KSActionProcessor *)processor;

// Returns the KSActionPipe for this action to use for input. This method never
// returns nil.
- (KSActionPipe *)inPipe;

// Sets the KSActionPipe for this action to use for input. If |inpipe| is nil,
// the input pipe will be re-set to a new, empty KSActionPipe.
- (void)setInPipe:(KSActionPipe *)inpipe;

// Returns the KSActionPipe for this action to use for output. This method never
// returns nil.
- (KSActionPipe *)outPipe;

// Sets the KSActionPipe for this action to use for output. If |outpipe| is nil,
// the output pipe will be re-set to a new, empty KSActionPipe.
- (void)setOutPipe:(KSActionPipe *)outpipe;

// Returns YES if the action is currently running, NO otherwise. Subclasses
// should NOT need to override this method. It returns YES if this action (self)
// is the "current action" on its |processor|, NO otherwise. This should be the
// correct "isRunning" status for the majority of KSAction subclasses.
- (BOOL)isRunning;

//
// Methods that subclasses are likely to need to override.
//

// This message is sent by a KSActionProcessor when the action is supposed to
// begin. This method may be synchronous or asynchronous. When the action is
// complete, the -[KSActionProcessor finishedProcessing:successfully:] message
// should be sent to the KSActionProcessor on which this action is running (as
// obtained from the -processor message).
//
// Note that the -finishedProcessing:successfully: message should always be sent
// to the processor instance eventually. This is the only way the processor
// will know that the action has finished. The only caveat to this rule is if
// your action is terminated by the -terminateAction method, then you should NOT
// send -finishedProcessing:successfully: to the action processor.
//
// Also, keep in mind that, as with all Google code, this method is NOT allowed
// to throw any exceptions. If you use an API that is documented to throw (or
// is likely to throw), such as NSTask, it is your responsibility to catch that
// and handle it appropriately.
//
// *** Note that a KSAction may only be on one KSActionProcessor at a time. ***
- (void)performAction;

// This message is sent by the KSActionProcessor when it needs to prematurely
// terminate a running action. When this message is sent you should immediately
// stop all processing before returning from this method.
//
// This method is optional. If your action doesn't need to do any cleanup, or
// if it's synchronous (meaning, it will be done when -performAction
// returns), this method does not need to be overridden.
//
// Subclasses should NOT send -finishedProcessing:successfully: to the action
// processor from this method. If this method is called, the action processor
// already knows that you're finishing, and therefore, it's unnecessary to
// send that message.
- (void)terminateAction;

@end

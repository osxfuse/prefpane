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
#import "KSAction.h"

@class KSActionProcessor;

// KSMultiAction
//
// An *abstract* KSAction class that encapsulates an action that uses an 
// internal KSActionProcessor to process "sub actions". An example of where this
// may be used is with a "prefetch" downloader. The "prefetch" action may create
// a number of "sub" KSDownloadActions to prefetch files. 
//
// This class differs from a KSCompositeAction because a composite joins
// multiple actions into one logical action; if any of the actions fail, the 
// composite as a whole fails. A KSMultiAction is looser in that a failed sub
// action does not necessarily cause the action as a whole to fail. Also, the
// meta action subclass itself may do some processing in addition to the sub
// actions.
//  
// By default, KSMultiActions report that they completed successfully. If a 
// subclass needs to control whether it complets successfully, it can override
// -processingDone: (called by the |subProcessor|) to tell [self processor] that
// the KSMultiAction failed. See KSCheckAtion for an example.
//
// KSCompositeAction = subaction_1 + subaction_2 + subaction_n
// KSMultiAction = KSMultiActionSubclass + subaction1 + subaction2 + subactionN
//
@interface KSMultiAction : KSAction {
 @private
  KSActionProcessor *subProcessor_;
  int subActionsProcessed_;
}

// Returns the number of actions that will be processed by the subProcessor.
- (int)subActionsProcessed;

@end


// "Protected" methods that only subclasses should call
@interface KSMultiAction (ProtectedMethods)

// Returns the subProcessor used by this KSMultiAction instance. Never returns
// nil.
- (KSActionProcessor *)subProcessor;

@end

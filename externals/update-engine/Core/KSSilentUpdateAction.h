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
#import "KSMultiUpdateAction.h"

@class KSUpdateEngine, KSActionProcessor;

// KSSilentUpdateAction
//
// This concrete KSMultiAction subclass that takes input from its inPipe, which
// must be an array of product dictionaries (see KSUpdateInfo.h for more details
// on the format), and messages the engine_'s delegate to find out which of
// the products in the array should be installed. Based on the response from the
// delegate, KSUpdateActions will be created and run on an internal
// KSActionProcessor.  This action never adds any actions to the processor on
// which it itself is running. This action finishes once all of its subactions
// (if any) complete.
//
// Upon completion, this action's outPipe will contain the number of
// KSUpdateActions enqueued, wrapped in an NSNumber.
//
// Sample code to create a checker and a prompt connected via a pipe.
//
//   KSActionProcessor *ap = ...
//   KSUpdateCheckAction *checker = ...
//
//   KSAction *update = [KSSilentUpdateActionactionWithEngine:engine_];
//
//   KSActionPipe *pipe = [KSActionPipe pipe];
//   [checker setOutPipe:pipe];
//   [update setInPipe:pipe];
//
//   [ap enqueueAction:checker];
//   [ap enqueueAction:update];
// 
//   [ap startProcessing];
//
// See KSUpdateEngine.m for another example of using KSSilentUpdateAction.
@interface KSSilentUpdateAction : KSMultiUpdateAction

// See KSMutliUpdateAction's interface

@end

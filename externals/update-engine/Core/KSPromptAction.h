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

// KSPromptAction
//
// This concrete KSMultiAction subclass takes input from its inPipe, which must
// be an array of product dictionaries (see KSServer.h for more details on the
// dictionary format), and messages the engine_'s delegate to find out which
// of the products in the array should be installed. Based on the response from
// the delegate, KSUpdateActions will be created and run on an internal
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
//   KSPromptAction *prompt = [KSPromptAction actionWithEngine:engine_];
//
//   KSActionPipe *pipe = [KSActionPipe pipe];
//   [checker setOutPipe:pipe];
//   [prompt setInPipe:pipe];
//
//   [ap enqueueAction:checker];
//   [ap enqueueAction:prompt];
// 
//   [ap startProcessing];
//
// See KSUpdateEngine.m for another example of using KSPromptAction.
@interface KSPromptAction : KSMultiUpdateAction 

// See KSMultiUpdateAction's interface

@end

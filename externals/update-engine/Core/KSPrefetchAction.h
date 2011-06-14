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
#import "KSMultiAction.h"

@class KSUpdateEngine, KSActionProcessor;

// KSPrefetchAction
//
// This concrete KSMultiAction subclass that takes input from its inPipe, which
// must be an array of product dictionaries (see KSServer.h for more details on
// the dictionary format), and messages the engine_'s delegate to find out
// which of the products in the array should be prefetched. Based on the
// response from the delegate, KSDownloadActions will be created and run on an
// internal KSActionProcessor.  This action never adds any actions to the
// processor on which it itself is running. This action finishes once all of its
// subactions (if any) complete.
//
// This class can be used to download product updates before prompting the user
// to install the update. This way, when the user does the install, they do not
// need to wait for the download to complete.
//
// This action always sets its outPipe's contents to be the exact same as its
// inPipe contents.
//
// Sample code to create a checker and a prefetcher connected via a pipe.
//
//   KSActionProcessor *ap = ...
//   KSUpdateCheckAction *checker = ...
//
//   KSPrefetchAction *prefetch = [KSPromptAction actionWithEngine:engine_];
//
//   KSActionPipe *pipe = [KSActionPipe pipe];
//   [checker setOutPipe:pipe];
//   [prefetch setInPipe:pipe];
//
//   [ap enqueueAction:checker];
//   [ap enqueueAction:prefetch];
// 
//   [ap startProcessing];
//
// See KSUpdateEngine.m for another example of using KSPrefetchAction.
@interface KSPrefetchAction : KSMultiAction {
 @private
  KSUpdateEngine *engine_;
}

// Returns an autoreleased KSPrefetchAction associated with |engine|
+ (id)actionWithEngine:(KSUpdateEngine *)engine;

// Designated initializer. Returns a KSPrefetchAction associated with |engine|
- (id)initWithEngine:(KSUpdateEngine *)engine;

@end

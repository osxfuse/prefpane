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

// KSCompositeAction
//
// A KSCompositeAction is a KSAction that is composed of other KSActions. This
// is the classic Composite Design Pattern. A KSCompositeAction will create an
// internal KSActionProcessor to run all of its contained actions. The actions
// will be run in the order defined by the |actions| array that was passed to 
// the initializer.
//
// All contained actions must complete successfully for the composite action
// itself to complete successfully. In other words, if any contained KSAction
// fails, the KSCompositeAction as a whole will fail. If any action fails, all
// processing of the contained KSActions will immediately stop.
//
// Sample code:
//
//   KSActionProcessor *ap = ... get or create a KSActionProcessor ...
//
//   KSAction *a1 = ... create a KSAction ...
//   KSAction *a2 = ... create another KSAction ...
//   KSAction *a2 = ... and one more ...
//
//   NSArray *actions = [NSArray arrayWithObjects:a1, a2, a3, nil];
//
//   KSAction *composite = [KSCompositeAction actionWithActions:actions];
//   [ap enqueueAction:composite];
//
//   [ap startProcessing];
//
// In the above code, a KSCompositeAction is created from 3 other actions. The
// composite action will run action |a1| first, then |a2|, and finally |a3|. If
// any of the actions fail, the composite action will immediately stop running
// and will report that it failed. All contained actions must complete
// successfully for the KSCompositeAction itself to complete successfully.
//
// Upon completion, the contents of the composite action's outPipe is the same
// as the contents of the last action's outPipe. Before completion, the contents
// of the output is undefined.
@interface KSCompositeAction : KSAction {
 @private
  NSArray *actions_;
  KSActionProcessor *subProcessor_;
  NSMutableArray *completedActions_;
}

// Convenience method that returns an autoreleased instance that is composed of 
// the KSActions in the |actions| array.
+ (id)actionWithActions:(NSArray *)actions;

// Returns an initialized instance that is composed of the KSActions in the
// |actions| array. |actions| must not be empty or nil.
- (id)initWithActions:(NSArray *)actions;

// Getter that returns the array of actions that this instance is composed of.
- (NSArray *)actions;

// Returns an array of the actions that completed successfully. If none have 
// completed successfully, nil is returned. If an action runs and fails, it will
// not be included in this array.
- (NSArray *)completedActions;

// Returns YES if the KSCompositeAction as a whole completed successfully. This
// is determined by verifying that that completedActions array matches the
// actions array.
- (BOOL)completedSuccessfully;

@end

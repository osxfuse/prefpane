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

@class KSUpdateEngine;

// KSMultiUpdateAction
//
// Abstract action that encapsulates running multiple sub-KSUpdateActions. Two
// concrete subclasses of this class are KSSilentUpdateAction and
// KSPromptAction, each of which differ only in how they figure out which of
// the available updates should be installed.
@interface KSMultiUpdateAction : KSMultiAction {
 @private
  KSUpdateEngine *engine_;
}

// Returns an autoreleased action associated with the given |engine|
+ (id)actionWithEngine:(KSUpdateEngine *)engine;

// Designated initializer. Returns an action associated with |engine|
- (id)initWithEngine:(KSUpdateEngine *)engine;

// Returns the KSUpdateEngine instance for this KSMultiUpdateAction
- (KSUpdateEngine *)engine;

@end


// These methods MUST be implemented by subclasses. These methods are called
// from the -performAction method and are required.
@interface KSMultiUpdateAction (PureVirtualMethods)

// Given an array of KSUpdateInfos. Returns an array of KSUpdateInfos for the
// products that should be updated.
- (NSArray *)productsToUpdateFromAvailable:(NSArray *)availableUpdates;

@end

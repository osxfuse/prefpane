// Copyright 2009 Google Inc.
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

// UECatalogFilterAction takes a catalog of image url strings from the
// action pipe, and then filters them based on a predicate.
//
@interface UECatalogFilterAction : KSAction {
 @private
  NSPredicate *filterPredicate_;
}

// Initialze a new filter action with the given predicate.  Pass nil
// to perform no filtering.
- (id)initWithPredicate:(NSPredicate *)predicate;

@end  // UECatalogFilterAction

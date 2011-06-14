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

#import "UECatalogFilterAction.h"

// Update Engine action classes.
#import "KSActionPipe.h"
#import "KSActionProcessor.h"

// Action sample header
#import "UENotifications.h"


@implementation UECatalogFilterAction

- (id)initWithPredicate:(NSPredicate *)predicate {
  if ((self = [super init])) {
    filterPredicate_ = [predicate retain];
  }

  return self;

}  // initWithPredicate


- (id)init {
  return [self initWithPredicate:nil];

}  // init


- (void)dealloc {
  [filterPredicate_ release];
  [super dealloc];

}  // dealloc


- (void)performAction {
  // Pick up the array of url strings from the previous stage in the pipelne.
  NSArray *imageURLStrings = [[self inPipe] contents];

  UEPostMessage(@"Perfoming UECatalogFilterAction on %d url strings",
                [imageURLStrings count]);

  // If we have a predicte, filter the incoming array.
  NSArray *filteredURLStrings;
  if (filterPredicate_) {
    filteredURLStrings =
      [imageURLStrings filteredArrayUsingPredicate:filterPredicate_];
  } else {
    filteredURLStrings = imageURLStrings;
  }

  UEPostMessage(@"UECatalogFilterAction Putting %d url string array into pipe",
                [filteredURLStrings count]);

  // Send the results to the next action in the chain.
  [[self outPipe] setContents:filteredURLStrings];

  // All done!
  [[self processor] finishedProcessing:self successfully:YES];

}  // performAction

@end  // UECatalogFilterAction

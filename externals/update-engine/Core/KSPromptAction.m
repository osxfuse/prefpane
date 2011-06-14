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

#import "KSPromptAction.h"
#import "KSUpdateEngine.h"
#import "KSActionProcessor.h"
#import "KSActionPipe.h"
#import "KSUpdateInfo.h"
#import "KSUpdateAction.h"
#import "KSFrameworkStats.h"


@implementation KSPromptAction

// A quick note about stats:
//
// We collect 3 stats in this method.
// kStatPrompts - which is the number of times we send a list of avail updates
// kStatPromptApps - which is the number of apps that we prompted about
// kStatPromptUpdates - which is the number of apps that the user was prompted
//                      for, and the user said "yes" to installing the update
- (NSArray *)productsToUpdateFromAvailable:(NSArray *)availableUpdates {
  int numUpdates = [availableUpdates count];
  if (numUpdates > 0) {
    [[KSFrameworkStats sharedStats] incrementStat:kStatPrompts];
    [[KSFrameworkStats sharedStats] incrementStat:kStatPromptApps
                                               by:numUpdates];
  }
  
  NSArray *updatesToInstall = [[self engine] action:self
                               shouldUpdateProducts:availableUpdates];
  
  [[KSFrameworkStats sharedStats] incrementStat:kStatPromptUpdates
                                             by:[updatesToInstall count]];
  
  return updatesToInstall;
}

@end

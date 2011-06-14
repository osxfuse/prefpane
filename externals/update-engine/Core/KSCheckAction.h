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

// KSCheckAction
//
// This KSMultiAction runs one KSUpdateCheckAction for each unique server URL
// found in a ticket. The output of all the sub-KSUpdateCheckActions is
// collected and the aggregate output is set as this action's output (via its
// outPipe).
//
// Sample usage:
//   KSActionProcessor *ap = ...
//   NSArray *tickets = ... tickets that could be for any arbitrary URLs ...
//
//   KSAction *checker = [KSCheckAction actionWithTickets:tickets];
//
//   [ap enqueueAction:checker];
//   [ap startProcessing];
//
//   ... spin runloop until done ...
//   NSArray *agg = [[checker outPipe] contents];
//
// That last line will return an array with the aggregate output from all the
// sub-KSUpdateCheckActions.
//
// A KSCheckAction completes "successfully" if *any* of its
// sub-KSUpdateCheckActions complete successfully. They do not all need to be
// successfull in order for this class to be successful. This handles the case
// where one of the URLs for one of the KSUpdateCheckActions is bad but the
// rest are fine. In this case, we shouldn't fail the whole operation just from
// one bad URL. But in the case where the user has no internet connetion and
// ALL the sub-KSUpdateCheckActions fail, we do want to report that this multi-
// action failed.
//
@interface KSCheckAction : KSMultiAction {
 @private
  NSArray *tickets_;
  NSMutableArray *updateInfos_;  // Output for next action
  NSMutableDictionary *outOfBandData_;  // Output for next action
  NSDictionary *params_;
  KSUpdateEngine *engine_;
  BOOL wasSuccessful_;
}

// Returns an autoreleased KSCheckAction. See the designated initializer for
// more details.
+ (id)actionWithTickets:(NSArray *)tickets params:(NSDictionary *)params
                 engine:(KSUpdateEngine *)engine;
+ (id)actionWithTickets:(NSArray *)tickets params:(NSDictionary *)params;
+ (id)actionWithTickets:(NSArray *)tickets;

// Designated initializer. Returns a KSCheckAction that will create
// sub-KSUpdateCheckActions for each group of tickets to each unique server URL.
// |tickets| must be an array of KSTicket objects. The tickets do not need to
// point to the same server URL. A nil or empty array of tickets is allowed;
// this action will just immediately finish running and will return an empty
// output array as if no updates were available.
// If specified, |params| is an NSDictionary indexed by the keys in
// KSUpdateEngineParameters.h.  These paramaters are passed down to
// objects which may be created by this class.
- (id)initWithTickets:(NSArray *)tickets params:(NSDictionary *)params
               engine:(KSUpdateEngine *)engine;
- (id)initWithTickets:(NSArray *)tickets params:(NSDictionary *)params;
- (id)initWithTickets:(NSArray *)tickets;

@end


// API to configure KSCheckAction instances.
@interface KSCheckAction (Configuration)

// Returns the KSServer Class that will be used by KSCheckAction instances. The
// returned Class is guaranteed to be a subclass of KSServer. This method never
// returns nil. By default, the returned class is KSPlistServer.
+ (Class)serverClass;

// Sets the KSServer Class that KSCheckAction instances should use.
// |serverClass| MUST be a subclass of the KSServer abstract class. It will be
// ignored if it is not. Passing a value of nil will reset things back to its
// default value.
+ (void)setServerClass:(Class)serverClass;

@end

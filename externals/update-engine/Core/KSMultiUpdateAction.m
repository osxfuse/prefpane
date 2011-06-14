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

#import "KSMultiUpdateAction.h"

#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSFrameworkStats.h"
#import "KSTicket.h"
#import "KSUpdateAction.h"
#import "KSUpdateEngine.h"
#import "KSUpdateEngineParameters.h"
#import "KSUpdateInfo.h"

@interface KSMultiUpdateAction(PrivateMethods)
// Look up the ticket for a given productID in the UpdateEngine
// instance that we are holding on to.
- (KSTicket *)ticketForProductID:(NSString *)productID;
@end


@implementation KSMultiUpdateAction

+ (id)actionWithEngine:(KSUpdateEngine *)engine {
  return [[[self alloc] initWithEngine:engine] autorelease];
}

- (id)init {
  return [self initWithEngine:nil];
}

- (id)initWithEngine:(KSUpdateEngine *)engine {
  if ((self = [super init])) {
    engine_ = [engine retain];
    if (engine_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [engine_ release];
  [super dealloc];
}

- (KSUpdateEngine *)engine {
  return engine_;
}

- (KSTicket *)ticketForProductID:(NSString *)productID {
  KSTicketStore *store = [engine_ ticketStore];
  KSTicket *ticket = [store ticketForProductID:productID];
  return ticket;
}

- (void)performAction {
  NSArray *updates = [[self inPipe] contents];
  if (updates == nil) {
    GTMLoggerInfo(@"no updates available.");
    [[self processor] finishedProcessing:self successfully:YES];
    return;
  }

  _GTMDevAssert(engine_ != nil, @"engine_ must not be nil");

  // Make mutable copies of the updateInfos so we can update each one
  // with its corresponding ticket.
  NSMutableArray *availableUpdates = [NSMutableArray array];
  NSEnumerator *updateEnumerator = [updates objectEnumerator];
  KSUpdateInfo *info = nil;
  while ((info = [updateEnumerator nextObject])) {
    KSUpdateInfo *mutableInfo = [[info mutableCopy] autorelease];
    [availableUpdates addObject:mutableInfo];

    // Put the ticket into the info.
    KSTicket *ticket = [self ticketForProductID:[mutableInfo productID]];
    if (ticket != nil) [mutableInfo setValue:ticket forKey:kTicket];
  }

  // Call through to our "pure virtual" method that the concrete subclass
  // should have overridden to figure out which of the available prodcuts we
  // should actually update.
  NSArray *productsToUpdate =
    [self productsToUpdateFromAvailable:availableUpdates];

  // Filter our list of available updates to only those that we were told to
  // update. We don't simply use |productsToUpdate| because we may not be able
  // to trust the contents of that dictionary. Instead, we use productsToUpdate
  // to filter our dictionary, which we know we can trust.
  NSArray *filteredUpdates =
    [availableUpdates filteredArrayUsingPredicate:
     [NSPredicate predicateWithFormat:
      @"SELF IN %@", productsToUpdate]];

  NSArray *remainingUpdates =
    [availableUpdates filteredArrayUsingPredicate:
     [NSPredicate predicateWithFormat:
      @"NOT SELF IN %@", productsToUpdate]];

  // Set our outPipe to contain all of the updates that we did not do.
  [[self outPipe] setContents:remainingUpdates];

  // Make sure the union of our filteredUpdates and the remainingUpdates is
  // equal to our availableUpdates. We use NSSets because we don't care about
  // the order.
  _GTMDevAssert([[NSSet setWithArray:
             [filteredUpdates arrayByAddingObjectsFromArray:remainingUpdates]]
            isEqualToSet:[NSSet setWithArray:availableUpdates]],
           @"filteredUpdates + remainingUpdates should equal availableUpdates");

  // Use -description because it prints nicer than the way CF would format it
  GTMLoggerInfo(@"filteredUpdates=%@", [filteredUpdates description]);

  // Have we been initiated by the user?
  BOOL userInitiated =
    [[[engine_ params] objectForKey:kUpdateEngineUserInitiated] boolValue];

  // Convert each dictionary in |filteredUpdates| into a KSUpdateAction and
  // enqueue it on our subProcessor_
  NSEnumerator *filteredUpdateEnumerator = [filteredUpdates objectEnumerator];
  while ((info = [filteredUpdateEnumerator nextObject])) {
    id<KSCommandRunner> runner = [engine_ commandRunnerForAction:self];
    KSAction *action =
      [KSUpdateAction actionWithUpdateInfo:info
                                    runner:runner
                             userInitiated:userInitiated];
    [[self subProcessor] enqueueAction:action];
  }

  if ([[[self subProcessor] actions] count] == 0) {
    GTMLoggerInfo(@"No update actions created for filteredUpdates.");
    [[self processor] finishedProcessing:self successfully:YES];
    return;
  }

  [[self subProcessor] startProcessing];
}

- (void)processor:(KSActionProcessor *)processor
   startingAction:(KSAction *)action {
  KSUpdateAction *ua = (KSUpdateAction *)action;
  [[self engine] action:self
               starting:[ua updateInfo]];
}

- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  KSUpdateAction *ua = (KSUpdateAction *)action;

  // Record the return code from the update action
  NSNumber *rc = [ua returnCode];
  rc = (rc ? rc : [NSNumber numberWithInt:-1]);
  KSUpdateInfo *ui = [ua updateInfo];
  NSString *statKey = KSMakeProductStatKey([ui productID], kStatInstallRC);
  [[KSFrameworkStats sharedStats] setNumber:rc forStat:statKey];

  GTMLoggerInfo(@"Got return code %@ after updating %@", rc, ui);

  [[self engine] action:self
               finished:[ua updateInfo]
             wasSuccess:wasOK
            wantsReboot:[ua wantsReboot]];
}

// Unlike processor:startingAction and
// processor:finishedAction:successfully, runningAction:progress is
// called by the action itself, not by the action processor.
- (void)processor:(KSActionProcessor *)processor 
    runningAction:(KSAction *)action
         progress:(float)progress {
  KSUpdateAction *ua = (KSUpdateAction *)action;
  [[self engine] action:self
                running:[ua updateInfo]
               progress:[NSNumber numberWithFloat:progress]];
}

@end

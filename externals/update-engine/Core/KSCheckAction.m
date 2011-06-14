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

#import "KSCheckAction.h"

#import "KSActionConstants.h"
#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSFrameworkStats.h"
#import "KSPlistServer.h"
#import "KSTicket.h"
#import "KSTicketStore.h"
#import "KSUpdateCheckAction.h"


// The KSServer class used by this action is configurable. This variable holds
// the objc Class representing the KSServer subclass to use. This variable
// should not be directly accessed. Instead, the +serverClass class method
// should be used. That class method will return a default KSServer class if one
// is not set.
static Class gServerClass;  // Weak


@implementation KSCheckAction

+ (id)actionWithTickets:(NSArray *)tickets params:(NSDictionary *)params
                 engine:(KSUpdateEngine *)engine {
  return [[[self alloc] initWithTickets:tickets params:params engine:engine]
           autorelease];
}

+ (id)actionWithTickets:(NSArray *)tickets params:(NSDictionary *)params {
  return [[[self alloc] initWithTickets:tickets params:params] autorelease];
}

+ (id)actionWithTickets:(NSArray *)tickets {
  return [[[self alloc] initWithTickets:tickets] autorelease];
}

- (id)initWithTickets:(NSArray *)tickets params:(NSDictionary *)params
               engine:(KSUpdateEngine *)engine {
  if ((self = [super init])) {
    tickets_ = [tickets copy];
    params_ = [params retain];
    engine_ = [engine retain];
    updateInfos_ = [[NSMutableArray alloc] init];
    outOfBandData_ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (id)initWithTickets:(NSArray *)tickets params:(NSDictionary *)params {
  return [self initWithTickets:tickets params:params engine:nil];
}

- (id)initWithTickets:(NSArray *)tickets {
  return [self initWithTickets:tickets params:nil];
}

- (void)dealloc {
  [tickets_ release];
  [updateInfos_ release];
  [outOfBandData_ release];
  [params_ release];
  [engine_ release];
  [super dealloc];
}

- (void)performAction {
  NSDictionary *tixMap = [tickets_ ticketsByURL];
  if (tixMap == nil) {
    GTMLoggerInfo(@"no tickets to check on.");
    [[self outPipe] setContents:nil];
    [[self processor] finishedProcessing:self successfully:YES];
    return;
  }

  NSURL *url = nil;
  NSEnumerator *tixMapEnumerator = [tixMap keyEnumerator];

  while ((url = [tixMapEnumerator nextObject])) {
    NSArray *tickets = [tixMap objectForKey:url];
    [[KSFrameworkStats sharedStats] incrementStat:kStatTickets
                                               by:[tickets count]];

    // We don't want to check for products that are currently not installed, so
    // we need to filter the array of tickets to only those ticktes whose
    // existence checker indicates that they are currently installed.
    // NSPredicate makes this very easy.
    NSArray *filteredTickets =
      [tickets filteredArrayUsingPredicate:
       [NSPredicate predicateWithFormat:@"existenceChecker.exists == YES"]];

    if ([filteredTickets count] == 0)
      continue;

    GTMLoggerInfo(@"filteredTickets = %@", filteredTickets);
    [[KSFrameworkStats sharedStats] incrementStat:kStatValidTickets
                                               by:[filteredTickets count]];

    Class serverClass = [[self class] serverClass];
    // Creates a concrete KSServer instance using the designated initializer
    // declared on KSServer.  Pass along |engine_| so the server can call
    // delegate methods, if it needs to.
    KSServer *server = [[[serverClass alloc] initWithURL:url
                                                  params:params_
                                                  engine:engine_] autorelease];
    KSAction *checker = [KSUpdateCheckAction checkerWithServer:server
                                                       tickets:filteredTickets];
    [[self subProcessor] enqueueAction:checker];
  }

  if ([[[self subProcessor] actions] count] == 0) {
    GTMLoggerInfo(@"No checkers created.");
    [[self processor] finishedProcessing:self successfully:YES];
    return;
  }

  // Our output needs to be the aggregate of all our sub-action checkers' output
  // For now, we'll just set our output to a dictionary holding
  // |updateInfos_| and |outOfBandData_|.  When subactions complete,
  // we'll add their output to these two structures.

  [updateInfos_ removeAllObjects];
  [outOfBandData_ removeAllObjects];
  NSMutableDictionary *outPipeContents =
    [NSDictionary dictionaryWithObjectsAndKeys:
                  updateInfos_, KSActionUpdateInfosKey,
                  outOfBandData_, KSActionOutOfBandDataKey,
                  nil];
  [[self outPipe] setContents:outPipeContents];

  [[self subProcessor] startProcessing];
}

// KSActionProcessor callback method that will be called by our subProcessor
- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  [[KSFrameworkStats sharedStats] incrementStat:kStatChecks];
  if (wasOK) {
    // Get the checker's output contents and append it to our own output.
    NSDictionary *checkerOutput = [[action outPipe] contents];

    NSDictionary *oobData =
      [checkerOutput objectForKey:KSActionOutOfBandDataKey];
    NSURL *url = [checkerOutput objectForKey:KSActionServerURLKey];
    if (oobData && url) {
      [outOfBandData_ setObject:oobData forKey:[url description]];
    }

    NSArray *infos = [checkerOutput objectForKey:KSActionUpdateInfosKey];
    if (infos) {
      [updateInfos_ addObjectsFromArray:infos];
    }

    // See header comments about why this gets set to YES here.
    wasSuccessful_ = YES;
  } else {
    [[KSFrameworkStats sharedStats] incrementStat:kStatFailedChecks];
  }
}

// Overridden from KSMultiAction. Called by our subProcessor when it finishes.
// We tell our parent processor that we succeeded if *any* of our subactions
// succeeded.
- (void)processingDone:(KSActionProcessor *)processor {
  [[self processor] finishedProcessing:self successfully:wasSuccessful_];
}

@end


@implementation KSCheckAction (Configuration)

+ (Class)serverClass {
  return gServerClass ? gServerClass : [KSPlistServer class];
}

+ (void)setServerClass:(Class)serverClass {
  if (serverClass != Nil && ![serverClass isSubclassOfClass:[KSServer class]])
    return;
  gServerClass = serverClass;
}

@end

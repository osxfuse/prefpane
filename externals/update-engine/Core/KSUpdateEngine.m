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

#import "KSUpdateEngine.h"

#import <unistd.h>

#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSCheckAction.h"
#import "KSCommandRunner.h"
#import "KSFrameworkStats.h"
#import "KSOutOfBandDataAction.h"
#import "KSPrefetchAction.h"
#import "KSPromptAction.h"
#import "KSSilentUpdateAction.h"
#import "KSTicketStore.h"
#import "KSUpdateEngineParameters.h"
#import "GTMLogger.h"
#import "GTMNSString+FindFolder.h"
#import "GTMPath.h"


@interface KSUpdateEngine (PrivateMethods)

// Tiggers an update check for all of the tickets in the specified array. This
// method is called by -updateAllProducts and -updateProductWithProductID: to
// do the real work.
- (void)triggerUpdateForTickets:(NSArray *)tickets;

// Builds a new |stats_| dictionary, which has a mapping between a productID
// and the dictionary of stats provided by the delegate (assuming the delegate
// has implemented -engine:statsForProductID:).
- (void)updateStatsForTickets:(NSArray *)tickets;

@end

// The user-defined default ticket store path. If this value is nil, then the
// +defaultTicketStorePath method will generate a nice default value. This
// variable is typically only used in testing situations.
static NSString *gDefaultTicketStorePath = nil;

@implementation KSUpdateEngine

+ (NSString *)defaultTicketStorePath {
  return gDefaultTicketStorePath;
}

+ (void)setDefaultTicketStorePath:(NSString *)path {
  [gDefaultTicketStorePath autorelease];
  gDefaultTicketStorePath = [path copy];
}

+ (id)engineWithDelegate:(id)delegate {
  NSString *storePath = [self defaultTicketStorePath];
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath];
  return [self engineWithTicketStore:store delegate:delegate];
}

+ (id)engineWithTicketStore:(KSTicketStore *)store
                   delegate:(id)delegate {
  return [[[self alloc] initWithTicketStore:store
                                   delegate:delegate] autorelease];
}

- (id)init {
  return [self initWithTicketStore:nil delegate:nil];
}

- (id)initWithTicketStore:(KSTicketStore *)store
                 delegate:(id)delegate {
  if ((self = [super init])) {
    store_ = [store retain];
    [self setDelegate:delegate];
    [self stopAndReset];
    if (store_ == nil) {
      GTMLoggerDebug(@"error: created with nil ticket store");
      [self release];
      return nil;
    }
    params_ = [[NSDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [params_ release];
  [store_ release];
  [processor_ setDelegate:nil];
  [processor_ release];
  [stats_ release];
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p store=%@ delegate=%@>",
          [self class], self, store_, delegate_];
}

- (KSTicketStore *)ticketStore {
  return store_;
}

- (id)delegate {
  return delegate_;
}

- (void)setDelegate:(id)delegate {
  // We must retain/release our delegate because the delegate_ may be an NSProxy
  // which may not exist for the life of this KSUpdateEngine. In reality, this
  // only appears to be a problem on Tiger, but, we have to work on Tiger, too.
  @try {
    [delegate_ autorelease];
    delegate_ = [delegate retain];
  // COV_NF_START
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception setting delegate: %@", ex);
  }
  // COV_NF_END
}

// Triggers an update for all products in the main ticket store |store_|
- (void)updateAllProducts {
  _GTMDevAssert(store_ != nil, @"store_ must not be nil");
  [self triggerUpdateForTickets:[store_ tickets]];
}

- (void)updateProductWithProductID:(NSString *)productID {
  _GTMDevAssert(store_ != nil, @"store_ must not be nil");
  KSTicket *ticket = [store_ ticketForProductID:productID];
  if (ticket == nil) {
    GTMLoggerInfo(@"No ticket for product with Product ID %@", productID);
    return;
  }

  NSArray *oneTicket = [NSArray arrayWithObject:ticket];
  [self triggerUpdateForTickets:oneTicket];
}

- (BOOL)isUpdating {
  return [processor_ isProcessing];
}

- (void)stopAndReset {
  [processor_ stopProcessing];
  [processor_ autorelease];
  processor_ = [[KSActionProcessor alloc] initWithDelegate:self];
}

- (void)setParams:(NSDictionary *)params {
  [params_ autorelease];
  params_ = [params retain];
}

- (NSDictionary *)params {
  return params_;
}

- (KSStatsCollection *)statsCollection {
  return [KSFrameworkStats sharedStats];
}

- (void)setStatsCollection:(KSStatsCollection *)statsCollection {
  [KSFrameworkStats setSharedStats:statsCollection];
}

//
// KSActionProcessor delegate callbacks
//

- (void)processingStarted:(KSActionProcessor *)processor {
  GTMLoggerInfo(@"processor=%@", processor);
  @try {
    if ([delegate_ respondsToSelector:@selector(engineStarted:)])
      [delegate_ engineStarted:self];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
}

- (void)processingStopped:(KSActionProcessor *)processor {
  GTMLoggerInfo(@"processor=%@, wasSuccesful_=%d", processor, wasSuccessful_);
  @try {
    if ([delegate_ respondsToSelector:@selector(engineFinished:wasSuccess:)])
      [delegate_ engineFinished:self wasSuccess:wasSuccessful_];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
}

- (void)processor:(KSActionProcessor *)processor
   startingAction:(KSAction *)action {
  GTMLoggerInfo(@"processor=%@, action=%@", processor, action);
}

- (void)processor:(KSActionProcessor *)processor
   finishedAction:(KSAction *)action
     successfully:(BOOL)wasOK {
  GTMLoggerInfo(@"processor=%@, action=%@, wasOK=%d", processor, action, wasOK);
  if (!wasOK) {
    // If any of these actions fail (in reality, the only one that can possibly
    // fail is the KSCheckAction), we indicate that this fetch was not
    // successful, and we stop everything.
    wasSuccessful_ = NO;
    [self stopAndReset];
  }
}

// We override this NSObject method to ensure that KSUpdateEngine instances are
// always sent over DO byref, wrapped in an NSProtocolChecker. This means that
// KSUpdateEngine delegates who access us via a vended DO object will only have
// access to the methods declared in the KSUpdateEngine protocol (e.g., they
// will NOT have access to the -ticketStore method).
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
  NSProtocolChecker *pchecker =
    [NSProtocolChecker protocolCheckerWithTarget:self
                                        protocol:@protocol(KSUpdateEngine)];
  return [NSDistantObject proxyWithLocal:pchecker
                              connection:[encoder connection]];
}

@end  // KSUpdateEngine


@implementation KSUpdateEngine (KSUpdateEngineActionPrivateCallbackMethods)

- (NSArray *)action:(KSAction *)action shouldPrefetchProducts:(NSArray *)products {
  @try {
    if ([delegate_ respondsToSelector:@selector(engine:shouldPrefetchProducts:)])
      return [delegate_ engine:self shouldPrefetchProducts:products];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
  return products;  // if not implemented, assume we want to prefetch everything
}

- (NSArray *)action:(KSAction *)action
  shouldSilentlyUpdateProducts:(NSArray *)products {
  @try {
    if ([delegate_ respondsToSelector:@selector(engine:shouldSilentlyUpdateProducts:)])
      return [delegate_ engine:self shouldSilentlyUpdateProducts:products];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
  return products;  // if not implemented, assume we want to update everything
}

- (id<KSCommandRunner>)commandRunnerForAction:(KSAction *)action {
  @try {
    if ([delegate_ respondsToSelector:@selector(commandRunnerForEngine:)])
      return [delegate_ commandRunnerForEngine:self];
    else
      return [KSTaskCommandRunner commandRunner];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
  return nil;
}

- (void)action:(KSAction *)action
      starting:(KSUpdateInfo *)updateInfo {
  @try {
    // Inform the delegate that we are starting to update something
    if ([delegate_ respondsToSelector:@selector(engine:starting:)])
      [delegate_ engine:self starting:updateInfo];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
}

- (void)action:(KSAction *)action
       running:(KSUpdateInfo *)updateInfo
      progress:(NSNumber *)progress {
  @try {
    // Inform the delegate that we are starting to update something
    if ([delegate_ respondsToSelector:@selector(engine:running:progress:)])
      [delegate_ engine:self running:updateInfo progress:progress];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
}

- (void)action:(KSAction *)action
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {
  @try {
    // Inform the delegate that we finished updating something
    if ([delegate_ respondsToSelector:
         @selector(engine:finished:wasSuccess:wantsReboot:)])
      [delegate_ engine:self
               finished:updateInfo
             wasSuccess:wasSuccess
            wantsReboot:wantsReboot];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
}

- (NSArray *)action:(KSAction *)action shouldUpdateProducts:(NSArray *)products {
  @try {
    if ([delegate_ respondsToSelector:@selector(engine:shouldUpdateProducts:)])
      return [delegate_ engine:self shouldUpdateProducts:products];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
    products = nil;
  }
  return products;  // if not implemented, assume we want to update everything
}

@end  // KSUpdateEngineActionPrivateCallbackMethods


@implementation KSUpdateEngine (PrivateMethods)

- (void)updateStatsForTickets:(NSArray *)tickets {
  // Start over with a fresh stats directory for this update.
  [stats_ release];
  stats_ = [[NSMutableDictionary alloc] init];

  @try {
    if ([delegate_ respondsToSelector:@selector(engine:statsForProductID:)]) {
      NSEnumerator *ticketEnumerator = [tickets objectEnumerator];
      KSTicket *ticket;
      while ((ticket = [ticketEnumerator nextObject])) {
        NSDictionary *stats =
          [delegate_ engine:self statsForProductID:[ticket productID]];
        if (stats) {
          [stats_ setObject:stats forKey:[ticket productID]];
        }
      }
    }
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception talking to delegate: %@", ex);
  }
}

- (void)triggerUpdateForTickets:(NSArray *)tickets {
  _GTMDevAssert(processor_ != nil, @"processor must not be nil");

  [self updateStatsForTickets:tickets];

  // Will be set to NO if any of the KSActions fail. But note that the only
  // one of these KSActions that can ever fail is the KSCheckAction.
  wasSuccessful_ = YES;

  // Add the product stats to the server parameters.
  NSMutableDictionary *params = [[params_ mutableCopy] autorelease];
  if (stats_) [params setObject:stats_ forKey:kUpdateEngineProductStats];

  // Build a KSMultiAction pipeline:

  KSAction *check    = [KSCheckAction actionWithTickets:tickets
                                                 params:params
                                                 engine:self];
  KSAction *oob      = [KSOutOfBandDataAction actionWithEngine:self];
  KSAction *prefetch = [KSPrefetchAction actionWithEngine:self];
  KSAction *silent   = [KSSilentUpdateAction actionWithEngine:self];
  KSAction *prompt   = [KSPromptAction actionWithEngine:self];

  [KSActionPipe bondFrom:check to:oob];
  [KSActionPipe bondFrom:oob to:prefetch];
  [KSActionPipe bondFrom:prefetch to:silent];
  [KSActionPipe bondFrom:silent to:prompt];

  [processor_ enqueueAction:check];
  [processor_ enqueueAction:oob];
  [processor_ enqueueAction:prefetch];
  [processor_ enqueueAction:silent];
  [processor_ enqueueAction:prompt];

  [processor_ startProcessing];
}

@end  // PrivateMethods

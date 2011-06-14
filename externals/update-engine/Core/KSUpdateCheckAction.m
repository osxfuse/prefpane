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

#import "KSUpdateCheckAction.h"

#import "GDataHTTPFetcher.h"
#import "KSActionConstants.h"
#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSFetcherFactory.h"
#import "KSServer.h"
#import "KSTicket.h"
#import "KSUpdateAction.h"


@interface KSUpdateCheckAction (FetcherCallbacks)

// A KSUpdateCheckAction may ask for information via GDataHTTPFetcher
// which is async.  These are callbacks passed to [GDataHTTPFetcher
// beginFetchingWithDelegate::::] to let us know what happened.
- (void)fetcher:(GDataHTTPFetcher *)fetcher finishedWithData:(NSData *)data;
- (void)fetcher:(GDataHTTPFetcher *)fetcher failedWithError:(NSError *)error;

@end


@implementation KSUpdateCheckAction

+ (id)checkerWithServer:(KSServer *)server tickets:(NSArray *)tickets {
  return [[[KSUpdateCheckAction alloc] initWithServer:server
                                              tickets:tickets] autorelease];
}

- (id)init {
  return [self initWithServer:nil tickets:nil];
}

- (id)initWithServer:(KSServer *)server tickets:(NSArray *)tickets {
  return [self initWithFetcherFactory:[KSFetcherFactory factory]
                               server:server
                              tickets:tickets];
}

- (id)initWithFetcherFactory:(KSFetcherFactory *)fetcherFactory
                      server:(KSServer *)server
                     tickets:(NSArray *)tickets {
  if ((self = [super init])) {
    if ((fetcherFactory == nil) ||
        (server == nil) ||
        ([tickets count] == 0)) {
      [self release];
      return nil;
    }
    // check invariant; make sure all tickets point to the same server URL
    if ([tickets count] > 1) {
      KSTicket *first = [tickets objectAtIndex:0];
      NSEnumerator *tenum = [tickets objectEnumerator];
      KSTicket *t = nil;
      while ((t = [tenum nextObject])) {
        if (![[first serverURL] isEqual:[t serverURL]]) {
          GTMLoggerInfo(@"UpdateChecker passed tickets with different URLs?");
          [self release];
          return nil;
        }
      }
    }
    fetcherFactory_ = [fetcherFactory retain];
    server_ = [server retain];
    tickets_ = [tickets copy];
    fetchers_ = [[NSMutableArray alloc] init];
    allSuccessful_ = YES;  // so far...
  }
  return self;
}

- (void)dealloc {
  [fetcherFactory_ release];
  [server_ release];
  [tickets_ release];
  [fetchers_ release];
  [super dealloc];
}

// Override of -[KSAction performAction] to define ourselves as an
// action object.  Like KSAction, we are called from our owning
// KSActionProcessor.  This method happens to be async.
- (void)performAction {
  NSArray *requests = [server_ requestsForTickets:tickets_];

  // Try and make debugging easier
  NSEnumerator *renum = [requests objectEnumerator];
  NSURLRequest *req = nil;

#ifdef DEBUG
  int x = 0;
  while ((req = [renum nextObject])) {
    NSData *data = [req HTTPBody];
    // %.*s since we need length (data not NULL-terminated)
    GTMLoggerDebug(@"** XML request %d:\n%.*s", x++,
                  [data length], (char*)[data bytes]);
  }
#endif

  renum = [requests objectEnumerator];
  while ((req = [renum nextObject])) {
    GDataHTTPFetcher *fetcher = [fetcherFactory_ createFetcherForRequest:req];
    _GTMDevAssert(fetcher, @"no fetcher");
    [fetchers_ addObject:fetcher];
    [fetcher beginFetchWithDelegate:self
                  didFinishSelector:@selector(fetcher:finishedWithData:)
                    didFailSelector:@selector(fetcher:failedWithError:)];
  }
}

- (void)terminateAction {
  NSEnumerator *fenum = [fetchers_ objectEnumerator];
  GDataHTTPFetcher *fetcher = nil;
  while ((fetcher = [fenum nextObject])) {
    if ([fetcher isFetching]) {
      [fetcher stopFetching];
    }
  }
  [fetchers_ removeAllObjects];
}

- (void)requestFinishedForFetcher:(GDataHTTPFetcher *)fetcher success:(BOOL)successful {
  [fetchers_ removeObject:fetcher];
  if (successful == NO)
    allSuccessful_ = NO;
  if ([fetchers_ count] == 0) {
    [[self processor] finishedProcessing:self successfully:allSuccessful_];
  }
}

- (int)outstandingRequests {
  return [fetchers_ count];
}

- (id)delegate {
  return delegate_;
}

- (void)setDelegate:(id)delegate {
  delegate_ = delegate;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p server=%@ tickets=%@>",
          [self class], self, server_, tickets_];
}

@end  // KSUpdateCheckAction


@implementation KSUpdateCheckAction (FetcherCallbacks)

- (void)fetcher:(GDataHTTPFetcher *)fetcher finishedWithData:(NSData *)data {
  NSURLResponse *response = [fetcher response];
  NSString *prettyData = [server_ prettyPrintResponse:response data:data];
  GTMLoggerDebug(@"** XML response:\n%@", prettyData);

  NSDictionary *oob;
  NSArray *updateInfos = [server_ updateInfosForResponse:response
                                                    data:data
                                           outOfBandData:&oob];
  KSTicket *first = [tickets_ objectAtIndex:0];
  // If |oob| is nil for this dictionary creation, life is still good.
  // The outgoing dictionary just won't have an out-of-band data
  // element.
  NSDictionary *results =
    [NSDictionary dictionaryWithObjectsAndKeys:
                  [first serverURL], KSActionServerURLKey,
                  updateInfos, KSActionUpdateInfosKey,
                  oob, KSActionOutOfBandDataKey,
                  nil];
  [[self outPipe] setContents:results];

  [self requestFinishedForFetcher:fetcher success:YES];
}

- (void)fetcher:(GDataHTTPFetcher *)fetcher failedWithError:(NSError *)error {
  GTMLoggerError(@"KSUpdateCheckAction failed with error %@", error);
  if ([[self delegate] respondsToSelector:@selector(fetcher:failedWithError:)])
    [[self delegate] fetcher:fetcher failedWithError:error];
  [self requestFinishedForFetcher:fetcher success:NO];
}

@end

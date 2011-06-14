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

#import <SenTestingKit/SenTestingKit.h>
#import "KSUpdateCheckAction.h"
#import "KSActionConstants.h"
#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSExistenceChecker.h"
#import "KSMockFetcherFactory.h"
#import "KSPlistServer.h"
#import "KSTicket.h"
#import "KSUpdateInfo.h"


@interface KSUpdateCheckActionTest : SenTestCase {
 @private
  KSActionProcessor *processor_;
  NSURL *url_;
  KSServer *splitServer_;
  KSServer *singleServer_;
  NSArray *twoTickets_;
  NSArray *lottaTickets_;
  // variables set by an action's callback for which we are the delegate
  int delegatedStatus_;
  NSData *delegatedData_;
  NSError *delegatedError_;
}
@end


/* --------------------------------------------------------------- */
// Helper classes for mocking.

// A mock KSServer which creates one request (and needs one fetcher) for each
// ticket.  The request data (HTTPBody) is a string-based number for each
// ticket; e.g. "0\0", "1\0".  The resultsForResponse creates a dictionary with
// the given data, reading the int from the request data.
@interface KSSplitMockServer : KSServer
@end

// A mock KSServer which creates one request (and only one fetcher) for ALL
// tickets.  The request data (HTTPBody) is a string-based number which is the
// count of tickets; e.g. "8\0".  The resultsForResponse creates a count of
// result dictionaries with a key of "NumberKey" and a value of the value from
// the response.
@interface KSSingleMockServer : KSServer
@end


/* --------------------------------------------------------------- */
@implementation KSSplitMockServer

// One request per ticket to create many fetchers
- (NSArray *)requestsForTickets:(NSArray *)tickets {
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:[tickets count]];
  for (int i = 0; i < [tickets count]; i++) {
    NSString *str = [NSString stringWithFormat:@"%d", i];
    NSData *data = [NSData dataWithBytes:[str UTF8String] length:[str length]];
    NSURL *url = [NSURL URLWithString:@"file://foo"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:data];
    [array addObject:request];
  }
  return array;
}

// One action, ever.
- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob {
  if (oob) *oob = nil;
  int x = 0;
  sscanf([data bytes], "%d", &x);
  NSDictionary *result = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:x]
                                                     forKey:@"NumberKey"];
  NSArray *array = [NSArray arrayWithObject:result];
  return array;
}

@end


/* --------------------------------------------------------------- */
@implementation KSSingleMockServer

// Only one request for all tickets
- (NSArray *)requestsForTickets:(NSArray *)tickets {
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
  NSString *countString = [NSString stringWithFormat:@"%d", [tickets count]];
  NSData *data = [countString dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url = [NSURL URLWithString:@"file://foo"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setHTTPMethod:@"POST"];
  [request setHTTPBody:data];
  [array addObject:request];
  return array;
}

// N KSActions, where N is the number embedded in data.
- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob {
  if (oob) *oob = nil;
  int x = 0;
  sscanf([data bytes], "%d", &x);
  NSMutableArray *array = [NSMutableArray array];
  for (int count = 0; count < x; count++) {
    NSDictionary *result = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:count]
                                                       forKey:@"NumberKey"];
    [array addObject:result];
  }
  return array;
}

@end


/* --------------------------------------------------------------- */
@implementation KSUpdateCheckActionTest

- (NSArray *)createTickets:(int)count forServer:(KSServer *)server {
  NSMutableArray *tickets = [[[NSMutableArray alloc] init] autorelease];
  for (int x = 0; x < count; x++) {
    NSString *productid = [NSString stringWithFormat:@"{guid-%d}", x];
    KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
    [tickets addObject:[KSTicket ticketWithProductID:productid
                                 version:@"1.0"
                                 existenceChecker:xc
                                 serverURL:url_]];
  }
  return tickets;
}

- (void)setUp {
  processor_ = [[KSActionProcessor alloc] init];

  url_ = [NSURL URLWithString:@"file://foo"];
  splitServer_ = [[KSSplitMockServer alloc] initWithURL:url_];
  singleServer_ = [[KSSingleMockServer alloc] initWithURL:url_];
  twoTickets_ = [[self createTickets:2 forServer:splitServer_] retain];
  lottaTickets_ = [[self createTickets:8 forServer:singleServer_] retain];
}

- (void)tearDown {
  [processor_ release];
  [splitServer_ release];
  [singleServer_ release];
  [twoTickets_ release];
  [lottaTickets_ release];
  [delegatedData_ release];
  [delegatedError_ release];
}

- (void)loopUntilEmpty {
  STAssertNotNil(processor_, nil);
  int count = 10;
  while (([processor_ isProcessing] == YES) && (count > 0)) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    count--;
  }
  STAssertTrue(count > 0, nil);  // make sure we didn't time out
}

- (void)confirmNoErrors {
  STAssertTrue(delegatedStatus_ == 0, nil);
  STAssertTrue(delegatedData_ == 0, nil);
  STAssertTrue(delegatedError_ == 0, nil);
}

- (void)runAction:(KSAction *)action {
  STAssertTrue([action isRunning] == NO, nil);
  [processor_ startProcessing];
  STAssertTrue([action isRunning] == YES, nil);
  [self loopUntilEmpty];
  STAssertTrue([action isRunning] == NO, nil);
}

- (void)testBasics {
  KSUpdateCheckAction *action = [KSUpdateCheckAction checkerWithServer:splitServer_
                                                     tickets:twoTickets_];
  STAssertNotNil(action, nil);
  STAssertTrue([[action description] length] > 1, nil);
  STAssertTrue([action outstandingRequests] == 0, nil);
  STAssertTrue([action isRunning] == NO, nil);

  action = [KSUpdateCheckAction checkerWithServer:splitServer_
                                          tickets:nil];
  STAssertNil(action, nil);

  action = [KSUpdateCheckAction checkerWithServer:splitServer_
                                          tickets:[NSArray array]];
  STAssertNil(action, nil);

  action = [[[KSUpdateCheckAction alloc] init] autorelease];
  STAssertNil(action, nil);
}

// Uses a real GDataHTTPFetcher and a KSPlistServer to fetch a canned server
// response, and ensures that the returned "result" dictionary from the
// KSUpdateCheckAction matches what we're expecting.
- (void)testServerResultDictionary {
  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];
  NSString *serverPlist = [mainBundle pathForResource:@"ServerSuccess"
                                               ofType:@"plist"];
  STAssertNotNil(serverPlist, nil);
  NSURL *serverURL = [NSURL fileURLWithPath:serverPlist];

  // Creates a KSServer for our "Plist server" that is really a text file
  // containing Plist-style XML
  KSServer *server = [KSPlistServer serverWithURL:serverURL];
  STAssertNotNil(server, nil);

  // Create a ticket that matches the one product in our plist server file
  KSTicket *ticket = [KSTicket ticketWithProductID:@"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST"
                                           version:@"0"
                                  existenceChecker:[KSPathExistenceChecker checkerWithPath:@"/"]
                                         serverURL:serverURL];
  STAssertNotNil(ticket, nil);

  KSUpdateCheckAction *action =
    [KSUpdateCheckAction checkerWithServer:server
                                   tickets:[NSArray arrayWithObject:ticket]];
  STAssertNotNil(action, nil);
  STAssertTrue([action outstandingRequests] == 0, nil);
  STAssertTrue([action isRunning] == NO, nil);

  [processor_ enqueueAction:action];
  [self runAction:action];
  [self confirmNoErrors];

  NSDictionary *dict =
    [NSDictionary dictionaryWithObjectsAndKeys:
     @"TyWAiay1UCIV0gqGbfjF4R009mg=", kServerCodeHash,
     @"TyWAiay1UCIV0gqGbfjF4R009mg=", @"Hash",
     [NSNumber numberWithInt:69042], kServerCodeSize,
     @"69042", @"Size",
     [NSURL URLWithString:@"file:///tmp/Test-SUCCESS.dmg"], kServerCodebaseURL,
     @"file:///tmp/Test-SUCCESS.dmg", @"Codebase",
     @"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST", kServerProductID,
     @"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST", @"ProductID",
     @"TRUEPREDICATE", @"Predicate",
     nil];

  // This is what the KSOutOfBandDataAction emits.
  NSArray *updateInfos = [NSArray arrayWithObject:dict];
  NSDictionary *expect =
    [NSDictionary dictionaryWithObjectsAndKeys:
                  serverURL, KSActionServerURLKey,
                  updateInfos, KSActionUpdateInfosKey,
                  nil];
  STAssertEqualObjects([[action outPipe] contents], expect, nil);
}

- (id)resultsFromMockTestWithServer:(KSServer *)server tickets:(NSArray *)tickets {
  NSString *bytes = [NSString stringWithFormat:@"%d", [tickets count]];
  NSData *data = [NSData dataWithBytes:[bytes UTF8String] length:[bytes length]];
  KSFetcherFactory *factory = [KSMockFetcherFactory alwaysFinishWithData:data];
  KSUpdateCheckAction *action = [[[KSUpdateCheckAction alloc]
                                   initWithFetcherFactory:factory
                                   server:server
                                   tickets:tickets] autorelease];
  STAssertNotNil(data, nil);
  STAssertNotNil(factory, nil);
  STAssertNotNil(action, nil);
  [processor_ enqueueAction:action];

  [self runAction:action];
  [self confirmNoErrors];

  return [[action outPipe] contents];
}

// Lots of mocks in this one which hide a bit of complexity.  The fetchers from
// the fetcher factory used here always claims to finish correctly, returning
// the data (as "results") passed into the factory.  The splitServer_ is a
// KSSplitServer, which has a seperate fetcher for each ticket ("split").  A
// KSSplitServer creates a string-encoded number (as NSData) for each ticket as
// requests (ignored by the fetcher).  Since the server uses the mock fetcher,
// the net result here is that we get a dictionary with "NumberKey" => X, where
// X is the number embedded in the data passed in to the factory (e.g. "2" for
// two tickets).
//
// In short, 2 tickets --> 2 fetchers --> 2 (exactly the same) results
- (void)testSplitServer {
  NSDictionary *results = [self resultsFromMockTestWithServer:splitServer_
                                                      tickets:twoTickets_];
  NSArray *updateInfos = [results objectForKey:KSActionUpdateInfosKey];

  STAssertTrue([updateInfos count] == 1, nil);

  NSDictionary *expect =
    [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:2]
                                forKey:@"NumberKey"];

  STAssertEqualObjects([updateInfos objectAtIndex:0], expect, nil);
}

// Similar to testSplitServer above, but we only use one fetcher for several
// tickets.  (The fetcher was specified on server creation.) Unlike the
// KSSplitServer, the KSSingleServer creates a result dictionary with a value of
// X, where X increments from 0 to to the value in the data passed into the
// factory (which is the number of tickets).
//
// In short, 8 tickets --> 1 fetcher --> 8 (unique) actions.
- (void)testSingleFetcher {
  NSDictionary *results = [self resultsFromMockTestWithServer:singleServer_
                                                      tickets:lottaTickets_];
  NSArray *updateInfos = [results objectForKey:KSActionUpdateInfosKey];

  STAssertTrue([updateInfos count] == [lottaTickets_ count], nil);
  for (int i = 0; i < [updateInfos count]; i++) {
    NSDictionary *expect =
      [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:i]
                                  forKey:@"NumberKey"];
    STAssertTrue([[updateInfos objectAtIndex:i] isEqual:expect], nil);
  }
}

// Test termination of a KSUpdateCheckAction.
- (void)testTermination {
  NSData *data = [NSData dataWithBytes:"hi" length:2];
  KSFetcherFactory *factory = [KSMockFetcherFactory alwaysFinishWithData:data];
  KSUpdateCheckAction *action = [[[KSUpdateCheckAction alloc]
                                   initWithFetcherFactory:factory
                                   server:splitServer_
                                   tickets:twoTickets_] autorelease];
  STAssertNotNil(data, nil);
  STAssertNotNil(factory, nil);
  STAssertNotNil(action, nil);
  [processor_ enqueueAction:action];

  // can't use runAction routine; we don't want to run the runloop.
  STAssertTrue([processor_ actionsCompleted] == 0, nil);
  STAssertTrue([action isRunning] == NO, nil);
  STAssertTrue([action outstandingRequests] == 0, nil);
  [processor_ startProcessing];
  STAssertTrue([action isRunning] == YES, nil);
  STAssertTrue([action outstandingRequests] > 0, nil);

  // intentionally no running of the run loop here so this action
  // can't finish.  (If it finished we couldn't cancel it!)

  [self confirmNoErrors];
  [processor_ stopProcessing];  // should call terminateAction
  STAssertTrue([action isRunning] == NO, nil);
  STAssertTrue([action outstandingRequests] == 0, nil);
  STAssertTrue([processor_ actionsCompleted] == 0, nil);
}

// Make sure bad input (tickets point to different servers) gets caught.
- (void)testBadTickets {
  NSMutableArray *mixedTickets = [NSMutableArray array];
  [mixedTickets addObjectsFromArray:twoTickets_];

  NSString *productid = [NSString stringWithFormat:@"{guid-%d}", 102];
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *altURL = [NSURL URLWithString:@"file://foo/alt/bar"];
  [mixedTickets addObject:[KSTicket ticketWithProductID:productid
                               version:@"1.0"
                               existenceChecker:xc
                               serverURL:altURL]];

  NSData *data = [NSData dataWithBytes:"hi" length:2];
  KSFetcherFactory *factory = [KSMockFetcherFactory alwaysFinishWithData:data];
  STAssertNotNil(data, nil);
  STAssertNotNil(factory, nil);

  KSUpdateCheckAction *action1 = [[[KSUpdateCheckAction alloc]
                                    initWithFetcherFactory:factory
                                                    server:splitServer_
                                                   tickets:mixedTickets]
                                   autorelease];
  STAssertNil(action1, nil);
  KSUpdateCheckAction *action2 = [[[KSUpdateCheckAction alloc]
                                    initWithFetcherFactory:factory
                                                    server:singleServer_
                                                   tickets:mixedTickets]
                                   autorelease];
  STAssertNil(action2, nil);
}

// Again, a funny fetcher factory which is supposed to fail
- (void)testFailedWithError {
  NSError *err = [NSError errorWithDomain:@"domain" code:55789 userInfo:nil];
  KSFetcherFactory *factory = [KSMockFetcherFactory alwaysFailWithError:err];
  KSUpdateCheckAction *action = [[[KSUpdateCheckAction alloc]
                                   initWithFetcherFactory:factory
                                   server:splitServer_
                                   tickets:twoTickets_] autorelease];
  STAssertNotNil(err, nil);
  STAssertNotNil(factory, nil);
  STAssertNotNil(action, nil);
  [action setDelegate:self];
  [processor_ enqueueAction:action];

  [self confirmNoErrors];
  [self runAction:action];

  // make sure the errors are exactly what we expected
  STAssertTrue(delegatedStatus_ == 0, nil);
  STAssertTrue(delegatedData_ == 0, nil);
  STAssertTrue([delegatedError_ isEqual:err], nil);
}

- (void)fetcher:(GDataHTTPFetcher *)fetcher failedWithStatus:(int)status
           data:(NSData *)data {
  delegatedStatus_ = status;
  delegatedData_ = [data retain];
}

- (void)fetcher:(GDataHTTPFetcher *)fetcher failedWithError:(NSError *)error {
  delegatedError_ = [error retain];
}

@end

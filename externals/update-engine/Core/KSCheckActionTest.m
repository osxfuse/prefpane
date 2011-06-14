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
#import "KSCheckAction.h"
#import "KSActionProcessor.h"
#import "KSExistenceChecker.h"
#import "KSTicket.h"
#import "KSUpdateEngine.h"


@interface KSCheckActionTest : SenTestCase
@end


@implementation KSCheckActionTest

- (void)testCreation {
  KSCheckAction *action = [[[KSCheckAction alloc] init] autorelease];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  action = [[[KSCheckAction alloc] initWithTickets:nil] autorelease];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  action = [KSCheckAction actionWithTickets:nil];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  action = [KSCheckAction actionWithTickets:[NSArray array]];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  NSDictionary *params = [NSDictionary dictionary];
  action = [KSCheckAction actionWithTickets:[NSArray array]
                                     params:params];
  STAssertNotNil(action, nil);
  STAssertEquals([action valueForKey:@"params_"], params, nil);

  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  action =
    [KSCheckAction actionWithTickets:[NSArray array]
                              params:params
                              engine:engine];
  STAssertNotNil(action, nil);
  STAssertEquals([action valueForKey:@"params_"], params, nil);
  STAssertEquals([action valueForKey:@"engine_"], engine, nil);
}

- (void)testSingleURL {
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];

  KSTicket *t1 = [KSTicket ticketWithProductID:@"foo"
                                       version:@"1"
                              existenceChecker:xc
                                     serverURL:[NSURL URLWithString:@"https://a.www.google.com"]];

  NSArray *tickets = [NSArray arrayWithObject:t1];

  KSCheckAction *action = [KSCheckAction actionWithTickets:tickets];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  [ap startProcessing];
  [ap stopProcessing];

  STAssertFalse([action isRunning], nil);
  STAssertEquals([action subActionsProcessed], 1, nil);
}

- (void)testSameURL {
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];

  KSTicket *t1 = [KSTicket ticketWithProductID:@"foo"
                                       version:@"1"
                              existenceChecker:xc
                                     serverURL:[NSURL URLWithString:@"https://a.www.google.com"]];

  KSTicket *t2 = [KSTicket ticketWithProductID:@"bar"
                                       version:@"1"
                              existenceChecker:xc
                                     serverURL:[NSURL URLWithString:@"https://a.www.google.com"]];

  NSArray *tickets = [NSArray arrayWithObjects:t1, t2, nil];

  KSCheckAction *action = [KSCheckAction actionWithTickets:tickets];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  [ap startProcessing];
  [ap stopProcessing];

  STAssertFalse([action isRunning], nil);
  STAssertEquals([action subActionsProcessed], 1, nil);
}

- (void)testDifferentURL {
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];

  KSTicket *t1 = [KSTicket ticketWithProductID:@"foo"
                                       version:@"1"
                              existenceChecker:xc
                                     serverURL:[NSURL URLWithString:@"https://a.www.google.com"]];

  KSTicket *t2 = [KSTicket ticketWithProductID:@"bar"
                                       version:@"1"
                              existenceChecker:xc
                                     serverURL:[NSURL URLWithString:@"https://b.www.google.com"]];

  NSArray *tickets = [NSArray arrayWithObjects:t1, t2, nil];

  KSCheckAction *action = [KSCheckAction actionWithTickets:tickets];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  [ap startProcessing];
  [ap stopProcessing];

  STAssertFalse([action isRunning], nil);
  STAssertEquals([action subActionsProcessed], 2, nil);
}

- (void)testBadXC {
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:
                            @"/DoesNotExist-123431f123asdvaweliznvliz"];

  KSTicket *t1 = [KSTicket ticketWithProductID:@"foo"
                                       version:@"1"
                              existenceChecker:xc
                                     serverURL:[NSURL URLWithString:@"https://a.www.google.com"]];

  NSArray *tickets = [NSArray arrayWithObject:t1];

  KSCheckAction *action = [KSCheckAction actionWithTickets:tickets];
  STAssertNotNil(action, nil);
  STAssertEquals([action subActionsProcessed], 0, nil);

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  [ap startProcessing];
  [ap stopProcessing];

  STAssertFalse([action isRunning], nil);

  // Should not have any subactions because the xc failed
  STAssertEquals([action subActionsProcessed], 0, nil);
}

@end

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
#import "KSPrefetchAction.h"
#import "KSUpdateEngine.h"
#import "KSUpdateInfo.h"
#import "KSActionPipe.h"
#import "KSActionProcessor.h"


@interface KSPrefetchActionTest : SenTestCase
@end


static NSString *const kTicketStorePath = @"/tmp/KSPrefetchActionTest.ticketstore";


@implementation KSPrefetchActionTest

- (void)setUp {
  [@"" writeToFile:kTicketStorePath atomically:YES];
  [KSUpdateEngine setDefaultTicketStorePath:kTicketStorePath];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeFileAtPath:kTicketStorePath handler:nil];
  [KSUpdateEngine setDefaultTicketStorePath:nil];
}

// KSUpdateEngineDelegate protocol method
- (NSArray *)engine:(KSUpdateEngine *)engine
shouldPrefetchProducts:(NSArray *)products {
  GTMLoggerInfo(@"products=%@", products);
  return [products filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:
           @"%K like 'allow*'", kServerProductID]];
}

- (void)loopUntilDone:(KSActionProcessor *)processor {
  int count = 50;
  while ([processor isProcessing] && (count > 0)) {
    NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:0.2];
    [[NSRunLoop currentRunLoop] runUntilDate:quick];
    count--;
  }
  STAssertFalse([processor isProcessing], nil);
}

- (void)testCreation {
  KSPrefetchAction *action = [KSPrefetchAction actionWithEngine:nil];
  STAssertNil(action, nil);
  
  action = [[[KSPrefetchAction alloc] init] autorelease];
  STAssertNil(action, nil);
  
  action = [[[KSPrefetchAction alloc] initWithEngine:nil] autorelease];
  STAssertNil(action, nil);
  
  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:nil];
  STAssertNotNil(engine, nil);
  action = [KSPrefetchAction actionWithEngine:engine];
  STAssertNotNil(action, nil);
}

- (void)testPrefetching {
  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  STAssertNotNil(engine, nil);
  
  KSPrefetchAction *action = [KSPrefetchAction actionWithEngine:engine];
  STAssertNotNil(action, nil);
  
  NSArray *availableProducts =
  [[NSArray alloc] initWithObjects:
   [NSDictionary dictionaryWithObjectsAndKeys:
    @"allow1", kServerProductID,
    [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
    [NSNumber numberWithInt:1], kServerCodeSize,
    @"zzz", kServerCodeHash,
    @"a://b", kServerMoreInfoURLString,
    nil],
   [NSDictionary dictionaryWithObjectsAndKeys:
    @"allow2", kServerProductID,
    [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
    [NSNumber numberWithInt:2], kServerCodeSize,
    @"xxx", kServerCodeHash,
    @"a://b", kServerMoreInfoURLString,
    nil],
   [NSDictionary dictionaryWithObjectsAndKeys:
    @"allow3", kServerProductID,
    [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
    [NSNumber numberWithInt:3], kServerCodeSize,
    @"yyy", kServerCodeHash,
    @"a://b", kServerMoreInfoURLString,
    nil],             
   [NSDictionary dictionaryWithObjectsAndKeys:
    @"deny1", kServerProductID,
    [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
    [NSNumber numberWithInt:3], kServerCodeSize,
    @"vvv", kServerCodeHash,
    @"a://b", kServerMoreInfoURLString,
    nil],
   nil];
  
  KSActionPipe *pipe = [KSActionPipe pipe];
  [pipe setContents:availableProducts];
  [action setInPipe:pipe];
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  
  [ap startProcessing];
  [self loopUntilDone:ap];
  STAssertFalse([ap isProcessing], nil);
  
  STAssertEquals([action subActionsProcessed], 3, nil);
}

- (void)testNegativeFiltering {
  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  STAssertNotNil(engine, nil);
  
  KSPrefetchAction *action = [KSPrefetchAction actionWithEngine:engine];
  STAssertNotNil(action, nil);
  
  NSArray *availableProducts =
  [[NSArray alloc] initWithObjects:
   [NSDictionary dictionaryWithObjectsAndKeys:
    @"deny1", kServerProductID,
    [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
    [NSNumber numberWithInt:1], kServerCodeSize,
    @"vvv", kServerCodeHash,
    @"a://b", kServerMoreInfoURLString,
    nil],
   [NSDictionary dictionaryWithObjectsAndKeys:
    @"deny2", kServerProductID,
    [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
    [NSNumber numberWithInt:2], kServerCodeSize,
    @"qqq", kServerCodeHash,
    @"a://b", kServerMoreInfoURLString,
    nil],
   nil];
  
  KSActionPipe *pipe = [KSActionPipe pipe];
  [pipe setContents:availableProducts];
  [action setInPipe:pipe];
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  
  [ap startProcessing];
  [self loopUntilDone:ap];
  STAssertFalse([ap isProcessing], nil);
  
  STAssertEquals([action subActionsProcessed], 0, nil);
}

- (void)testNoUpdates {
  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  STAssertNotNil(engine, nil);
  
  KSPrefetchAction *action = [KSPrefetchAction actionWithEngine:engine];
  STAssertNotNil(action, nil);
  
  KSActionPipe *pipe = [KSActionPipe pipe];
  [action setInPipe:pipe];  // This pipe is empty
  
  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];
  
  [ap startProcessing];
  [self loopUntilDone:ap];
  STAssertFalse([ap isProcessing], nil);
  
  STAssertEqualObjects([[action outPipe] contents], nil, nil);
}

@end

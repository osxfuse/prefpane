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
#import "KSMultiUpdateAction.h"

#import "KSActionPipe.h"
#import "KSActionProcessor.h"
#import "KSInstallAction.h"
#import "KSMemoryTicketStore.h"
#import "KSTicketStore.h"
#import "KSUpdateAction.h"
#import "KSUpdateEngine.h"
#import "KSUpdateEngineParameters.h"
#import "KSUpdateInfo.h"


@interface KSMultiUpdateActionTest : SenTestCase
@end


// Turn the abstract KSMultiUpdateAction into a concrete class we can
// instantiate.
@interface Concrete : KSMultiUpdateAction {
  // Hang on to the avaialble updates array we get from Update Engine
  // to verify that the ticket info has been added.
  NSArray *availableUpdates_;
}

- (NSArray *)availableUpdates;
@end

@implementation Concrete

- (NSArray *)productsToUpdateFromAvailable:(NSArray *)availableUpdates {
  // Hang on to the updates so we can check their tickettude after
  // the update has run.
  availableUpdates_ = [availableUpdates retain];

  return [availableUpdates filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:
           @"%K like 'allow*'", kServerProductID]];
}

- (void)dealloc {
  [availableUpdates_ release];
  [super dealloc];
}

- (NSArray *)availableUpdates {
  return availableUpdates_;
}

@end


// A fake action processor that hangs on to any actions that are enqueued,
// without actually running any.
@interface FakeSubProcessor : NSObject {
  NSMutableArray *actions_;
}

// Returns the collected actions.
- (NSArray *)actions;
@end

@implementation FakeSubProcessor

- (id)init {
  if ((self = [super init])) {
    actions_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [actions_ release];
  [super dealloc];
}

- (void)enqueueAction:(KSAction *)action {
  [actions_ addObject:action];
}

- (NSArray *)actions {
  return actions_;
}

- (void)finishedProcessing:(KSAction *)action successfully:(BOOL)successfully {
}

- (void)startProcessing {
}

@end


// A multi-action that provides a fake action subprocessor.  The actions
// created by KSMultiUpdateAction are accumulated, without being executed,
// and then later examined to make sure proper configuration values (in
// particular, user-initiated) filter down where they should.
@interface SubprocessAccessMultiAction : KSMultiUpdateAction {
  FakeSubProcessor *fakeSubProcessor_;
}

// Make sure the |uiValue| user-initiated value made it where it
// should have.
- (BOOL)verifyUserInitiatedValue:(BOOL)uiValue;
@end

@implementation SubprocessAccessMultiAction

- (KSActionProcessor *)processor {
  if (fakeSubProcessor_ == nil) {
    fakeSubProcessor_ = [[FakeSubProcessor alloc] init];
  }
  return (id)fakeSubProcessor_;
}

- (KSActionProcessor *)subProcessor {
  return [self processor];
}

- (NSArray *)productsToUpdateFromAvailable:(NSArray *)availableUpdates {
  return availableUpdates;
}

- (BOOL)verifyUserInitiatedValue:(BOOL)uiValue {

  if ([[fakeSubProcessor_ actions] count] == 0) {
    return NO;
  }

  BOOL success = YES;

  // Walk the fake sub processor, looking for Update actions.
  NSEnumerator *actionEnumerator =
    [[fakeSubProcessor_ actions] objectEnumerator];

  KSAction *action;
  while ((action = [actionEnumerator nextObject])) {
    if ([action isKindOfClass:[KSUpdateAction class]]) {
      // We got an Upate action.  Walk its actions looking for an Install
      // action.
      NSEnumerator *subActionEnumerator =
        [[(KSUpdateAction *)action actions] objectEnumerator];
      KSAction *subAction;
      while ((subAction = [subActionEnumerator nextObject])) {
        if ([subAction isKindOfClass:[KSInstallAction class]]) {
          // The Install action is what has the user-initiated value.
          // Make sure it jives with |uiValue|.
          NSNumber *userInitiatedNumber = [subAction valueForKey:@"ui_"];
          if (( [userInitiatedNumber boolValue] && !uiValue) ||
              (![userInitiatedNumber boolValue] &&  uiValue)) {
            success = NO;
            break;
          }
        }
      }
    }
  }
  return success;
}

@end

static NSString *const kTicketStorePath = @"/tmp/KSMultiUpdateActionTest.ticketstore";

@implementation KSMultiUpdateActionTest

- (void)setUp {
  [@"" writeToFile:kTicketStorePath atomically:YES];
  [KSUpdateEngine setDefaultTicketStorePath:kTicketStorePath];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeFileAtPath:kTicketStorePath handler:nil];
  [KSUpdateEngine setDefaultTicketStorePath:nil];
}

// KSUpdateEngineDelegate protocol method
- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine {
  return nil;
}

- (void)loopUntilDone:(KSActionProcessor *)processor {
  int count = 10;
  while ([processor isProcessing] && (count > 0)) {
    NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:0.2];
    [[NSRunLoop currentRunLoop] runUntilDate:quick];
    count--;
  }
  STAssertFalse([processor isProcessing], nil);
}

- (void)testCreation {
  Concrete *action = [Concrete actionWithEngine:nil];
  STAssertNil(action, nil);

  action = [[[Concrete alloc] init] autorelease];
  STAssertNil(action, nil);

  action = [[[Concrete alloc] initWithEngine:nil] autorelease];
  STAssertNil(action, nil);

  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  action = [Concrete actionWithEngine:engine];
  STAssertNotNil(action, nil);
  STAssertFalse([action isRunning], nil);

  // For the sake of code coverage, let's call this method even though we don't
  // really have a good way to test the functionality.
  [action terminateAction];
}


// Struct to hold the values used to create a ticket.
typedef struct RawTicketInfo {
  const char *productID;
  const char *version;
  const char *xcpath;
  const char *serverURL;
} RawTicketInfo;

static RawTicketInfo denyTix[] = {
  { "deny1", "123", "/blah", "http://google.com" },
  { "deny2", "234", "/blah", "http://google.com" },
};

- (KSTicketStore *)ticketStoreFromRawInfo:(RawTicketInfo *)rawBits
                                   length:(int)length {
  KSTicketStore *ticketStore = [[[KSMemoryTicketStore alloc] init] autorelease];
  RawTicketInfo *scan, *stop;
  scan = rawBits;
  stop = scan + length;
  while (scan < stop) {
    NSString *productID = [NSString stringWithUTF8String:scan->productID];
    NSString *version = [NSString stringWithUTF8String:scan->version];
    KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:
        [NSString stringWithUTF8String:scan->xcpath]];
    NSURL *serverURL =
      [NSURL URLWithString:[NSString stringWithUTF8String:scan->serverURL]];
    KSTicket *ticket =
      [KSTicket ticketWithProductID:productID
                            version:version
                   existenceChecker:xc
                          serverURL:serverURL];
    [ticketStore storeTicket:ticket];
    scan++;
  }
  return ticketStore;
}

- (void)testNegativeFiltering {
  KSTicketStore *store =
    [self ticketStoreFromRawInfo:denyTix
                          length:sizeof(denyTix) / sizeof(*denyTix)];
  KSUpdateEngine *engine =
    [KSUpdateEngine engineWithTicketStore:store delegate:self];
  STAssertNotNil(engine, nil);

  Concrete *action = [Concrete actionWithEngine:engine];
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

  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  [self loopUntilDone:ap];
  STAssertFalse([ap isProcessing], nil);
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);

  // Make sure the ticket made it to the update infos.
  NSEnumerator *updateEnumerator = [[action availableUpdates] objectEnumerator];
  KSUpdateInfo *info = nil;
  while ((info = [updateEnumerator nextObject])) {
    KSTicket *ticket = [info ticket];
    STAssertNotNil(ticket, nil);

    // Sanity check the ticket.
    NSString *ticketProductID = [ticket productID];
    NSString *infoProductID = [info productID];
    STAssertEqualObjects(ticketProductID, infoProductID, nil);
  }

  STAssertEquals([action subActionsProcessed], 0, nil);
}

- (void)testNoUpdates {
  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:self];
  STAssertNotNil(engine, nil);

  Concrete *action = [Concrete actionWithEngine:engine];
  STAssertNotNil(action, nil);

  KSActionPipe *pipe = [KSActionPipe pipe];
  [action setInPipe:pipe];  // This pipe is empty

  KSActionProcessor *ap = [[[KSActionProcessor alloc] init] autorelease];
  [ap enqueueAction:action];

  STAssertEqualsWithAccuracy([ap progress], 0.0f, 0.01, nil);
  [ap startProcessing];
  [self loopUntilDone:ap];
  STAssertFalse([ap isProcessing], nil);
  STAssertEqualsWithAccuracy([ap progress], 1.0f, 0.01, nil);

  STAssertEqualObjects([[action outPipe] contents], nil, nil);
}

- (void)testUserInitiatedFlag {

  // These values are common to the subsequent tests.
  NSNumber *yesNumber = [NSNumber numberWithBool:YES];
  NSNumber *noNumber = [NSNumber numberWithBool:NO];
  NSDictionary *params = nil;
  KSTicketStore *store = [[[KSMemoryTicketStore alloc] init] autorelease];
  KSUpdateEngine *engine =
    [KSUpdateEngine engineWithTicketStore:store delegate:nil];
  NSArray *pipeContents =
  [[[NSArray alloc] initWithObjects:
    [NSDictionary dictionaryWithObjectsAndKeys:
     @"bassenstein", kServerProductID,
     [NSURL URLWithString:@"a://b"], kServerCodebaseURL,
     [NSNumber numberWithInt:1], kServerCodeSize,
     @"vvv", kServerCodeHash,
     @"a://b", kServerMoreInfoURLString,
     nil],
    nil] autorelease];
  KSActionPipe *pipe = [KSActionPipe pipeWithContents:pipeContents];

  // YES for UserInitiated should filter down through the actions
  params = [NSDictionary dictionaryWithObjectsAndKeys:
                         yesNumber,
                         kUpdateEngineUserInitiated, nil];
  [engine setParams:params];
  SubprocessAccessMultiAction *action =
    [SubprocessAccessMultiAction actionWithEngine:engine];
  [action setInPipe:pipe];
  [action performAction];
  STAssertTrue([action verifyUserInitiatedValue:YES], nil);

  // NO for UserInitiated should filter down through the actions
  params = [NSDictionary dictionaryWithObjectsAndKeys:
                         noNumber,
                         kUpdateEngineUserInitiated, nil];
  [engine setParams:params];
  action = [SubprocessAccessMultiAction actionWithEngine:engine];
  [action setInPipe:pipe];
  [action performAction];
  STAssertTrue([action verifyUserInitiatedValue:NO], nil);

  // Default should be NO
  params = [NSDictionary dictionary];
  [engine setParams:params];
  action = [SubprocessAccessMultiAction actionWithEngine:engine];
  [action setInPipe:pipe];
  [action performAction];
  STAssertTrue([action verifyUserInitiatedValue:NO], nil);
}

@end

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
#import "KSUpdateEngine.h"
#import "KSUpdateEngine+Configuration.h"
#import "KSTicketStore.h"
#import "KSTicket.h"
#import "KSCommandRunner.h"
#import "KSExistenceChecker.h"
#import "KSUUID.h"
#import "KSFrameworkStats.h"


@interface KSUpdateEngineTest : SenTestCase {
 @private
  NSString *storePath_;
  NSURL *serverSuccessPlistURL_;
  NSURL *serverFailurePlistURL_;
}
@end


@interface UpdateEngineDelegate : NSObject {
 @private
  BOOL finished_;
  BOOL updateFailed_;
  BOOL engineFailed_;
  NSMutableArray *progressArray_;
}

- (BOOL)isFinished;
- (BOOL)updateFailed;
- (BOOL)engineFailed;
- (NSArray *)progressArray;

@end

@implementation UpdateEngineDelegate

- (id)init {
  if ((self = [super init])) {
    progressArray_ = [[NSMutableArray array] retain];
  }
  return self;
}

- (void)dealloc {
  [progressArray_ release];
  [super dealloc];
}

- (BOOL)isFinished {
  return finished_;
}

- (BOOL)updateFailed{
  return updateFailed_;
}

- (BOOL)engineFailed {
  return engineFailed_;
}

- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine {
  return [KSTaskCommandRunner commandRunner];
}

- (void)engine:(KSUpdateEngine *)engine
       running:(KSUpdateInfo *)updateInfo
      progress:(NSNumber *)progress {
  [progressArray_ addObject:progress];
}

- (NSArray *)progressArray {
  return progressArray_;
}


- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {
  if (wasSuccess == NO)
    updateFailed_ = YES;
}

- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess {
  finished_ = YES;
  engineFailed_ = !wasSuccess;
}

- (NSDictionary *)engine:(KSUpdateEngine *)engine
       statsForProductID:(NSString *)productID {
  return [NSDictionary dictionary];
}

@end  // UpdateEngineDelegate


// Helper class to serve as a KSUpdateEngine delegate and record all
// the delegate methods that it receives.
@interface CallbackTracker : NSObject {
 @private
  NSMutableArray *methods_;
}

- (NSArray *)methods;

@end

@implementation CallbackTracker

- (id)init {
  if ((self = [super init]))
    methods_ = [[NSMutableArray alloc] init];
  return self;
}

- (void)dealloc {
  [methods_ release];
  [super dealloc];
}

- (NSArray *)methods {
  return methods_;
}

- (NSArray *)engine:(KSUpdateEngine *)engine
shouldPrefetchProducts:(NSArray *)products {
  [methods_ addObject:NSStringFromSelector(_cmd)];
  return products;
}

- (NSArray *)engine:(KSUpdateEngine *)engine
shouldSilentlyUpdateProducts:(NSArray *)products {
  [methods_ addObject:NSStringFromSelector(_cmd)];
  return products;
}

- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine {
  [methods_ addObject:NSStringFromSelector(_cmd)];
  return nil;
}

- (void)engine:(KSUpdateEngine *)engine
      starting:(KSUpdateInfo *)updateInfo {
  [methods_ addObject:NSStringFromSelector(_cmd)];
}

- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {
  [methods_ addObject:NSStringFromSelector(_cmd)];
}

- (NSArray *)engine:(KSUpdateEngine *)engine
 shouldUpdateProducts:(NSArray *)products {
  [methods_ addObject:NSStringFromSelector(_cmd)];
  return products;
}

- (NSDictionary *)engine:(KSUpdateEngine *)engine
       statsForProductID:(NSString *)productID {
  [methods_ addObject:NSStringFromSelector(_cmd)];
  return nil;  // Make sure a nil stat directory doesn't cause an exception.
}

@end  // CallbackTracker


// Non-public methods that we want to call for testing.
@interface KSUpdateEngine (UpdateEngineFriend)
- (void)processingStarted:(KSActionProcessor *)processor;
- (void)processingStopped:(KSActionProcessor *)processor;
@end


// This delegate is bad because it throws an exception on every call. We throw
// NSStrings instead of NSExceptions to make sure we don't accidentally assume
// that NSExceptions are the only objects that can be thrown.
@interface BadDelegate : NSObject
// Nothing
@end

@implementation BadDelegate

- (void)engineStarted:(KSUpdateEngine *)engine {
  @throw @"blah";
}

- (NSDictionary *)engine:(KSUpdateEngine *)engine
       statsForProductID:(NSString *)productID {
  @throw @"blah";
}

- (void)engineFinished:(KSUpdateEngine *)engine wasSuccess:(BOOL)wasSuccess {
  @throw @"blah";
}

- (NSArray *)engine:(KSUpdateEngine *)engine
shouldPrefetchProducts:(NSArray *)products {
  @throw @"blah";
}

- (NSArray *)engine:(KSUpdateEngine *)engine
shouldSilentlyUpdateProducts:(NSArray *)products {
  @throw @"blah";
}

- (id<KSCommandRunner>)commandRunnerForEngine:(KSUpdateEngine *)engine {
  @throw @"blah";
}

- (void)engine:(KSUpdateEngine *)engine
      starting:(KSUpdateInfo *)updateInfo {
  @throw @"blah";
}

- (void)engine:(KSUpdateEngine *)engine
      finished:(KSUpdateInfo *)updateInfo
    wasSuccess:(BOOL)wasSuccess
   wantsReboot:(BOOL)wantsReboot {
  @throw @"blah";
}

- (NSArray *)engine:(KSUpdateEngine *)engine
 shouldUpdateProducts:(NSArray *)products {
  @throw @"blah";
}

- (void)engine:(KSUpdateEngine *)engine
       running:(KSUpdateInfo *)updateInfo
      progress:(NSNumber *)progress {
  @throw @"blah";
}

@end  // BadDelegate


@implementation KSUpdateEngineTest

- (void)setUp {
  // Generate a unique temp file name
  storePath_ = [[NSString stringWithFormat:@"/tmp/KSUpdateEngineTest.%@",
                 [KSUUID uuidString]] retain];
  STAssertNotNil(storePath_, nil);

  NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];

  // Get the path to a successful server plist response
  NSString *path = [mainBundle pathForResource:@"ServerSuccess"
                                        ofType:@"plist"];
  STAssertNotNil(path, nil);
  serverSuccessPlistURL_ = [[NSURL fileURLWithPath:path] retain];
  STAssertNotNil(serverSuccessPlistURL_, nil);

  // Copy the DMG referenced in the ServerSuccess.plist file to /tmp/
  NSString *dmg = [mainBundle pathForResource:@"Test-SUCCESS" ofType:@"dmg"];
  STAssertNotNil(path, nil);
  [[NSFileManager defaultManager] removeFileAtPath:@"/tmp/Test-SUCCESS.dmg"
                                           handler:nil];
  BOOL copied = [[NSFileManager defaultManager] copyPath:dmg
                                                  toPath:@"/tmp/Test-SUCCESS.dmg"
                                                 handler:nil];
  STAssertTrue(copied, nil);

  // Now, do the same thing for the "failure" XML and DMG
  path = [mainBundle pathForResource:@"ServerFailure" ofType:@"plist"];
  STAssertNotNil(path, nil);
  serverFailurePlistURL_ = [[NSURL fileURLWithPath:path] retain];
  STAssertNotNil(serverFailurePlistURL_, nil);

  dmg = [mainBundle pathForResource:@"Test-FAILURE" ofType:@"dmg"];
  STAssertNotNil(path, nil);
  [[NSFileManager defaultManager] removeFileAtPath:@"/tmp/Test-FAILURE.dmg" handler:nil];
  copied = [[NSFileManager defaultManager] copyPath:dmg
                                             toPath:@"/tmp/Test-FAILURE.dmg"
                                            handler:nil];
  STAssertTrue(copied, nil);

  [@"" writeToFile:storePath_ atomically:YES];
  [KSUpdateEngine setDefaultTicketStorePath:storePath_];
}

- (void)tearDown {
  [KSUpdateEngine setDefaultTicketStorePath:nil];
  [[NSFileManager defaultManager] removeFileAtPath:storePath_ handler:nil];
  NSString *lock = [storePath_ stringByAppendingPathExtension:@"lock"];
  [[NSFileManager defaultManager] removeFileAtPath:lock handler:nil];
  [[NSFileManager defaultManager] removeFileAtPath:@"/tmp/Test-SUCCESS.dmg" handler:nil];
  [[NSFileManager defaultManager] removeFileAtPath:@"/tmp/Test-FAILURE.dmg" handler:nil];
  [storePath_ release];
  [serverSuccessPlistURL_ release];
  [serverFailurePlistURL_ release];
}

- (void)loopUntilDone:(UpdateEngineDelegate *)delegate {
  int count = 50;
  while (![delegate isFinished] && (count > 0)) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    count--;
  }
  STAssertTrue(count > 0, nil);  // make sure we didn't time out
}

- (void)testCreation {
  KSUpdateEngine *engine = nil;

  engine = [[[KSUpdateEngine alloc] init] autorelease];
  STAssertNil(engine, nil);

  engine = [KSUpdateEngine engineWithDelegate:nil];
  STAssertNotNil(engine, nil);

  STAssertTrue([[engine description] length] > 1, nil);
  STAssertNotNil([engine ticketStore], nil);
  STAssertNil([engine delegate], nil);
  [engine setDelegate:@"not nil"];
  STAssertNotNil([engine delegate], nil);
  STAssertNil([engine statsCollection], nil);

  [KSUpdateEngine setDefaultTicketStorePath:nil];  // Reset to default
  NSString *defaultPath = [KSUpdateEngine defaultTicketStorePath];
  STAssertNil(defaultPath, nil);
  [KSUpdateEngine setDefaultTicketStorePath:@"foo"];
  STAssertEqualObjects([KSUpdateEngine defaultTicketStorePath],
                       @"foo", nil);
  [KSUpdateEngine setDefaultTicketStorePath:nil];  // Reset to default
  STAssertEqualObjects([KSUpdateEngine defaultTicketStorePath],
                       defaultPath, nil);
}

- (void)testDelegateCallbacks {
  CallbackTracker *tracker = [[[CallbackTracker alloc] init] autorelease];
  STAssertNotNil(tracker, nil);

  KSUpdateEngine *engine = [KSUpdateEngine engineWithDelegate:tracker];
  STAssertNotNil(engine, nil);

  STAssertNotNil([engine delegate], nil);
  STAssertEqualObjects([engine delegate], tracker, nil);

  // Call all the delegate methods.
  [engine action:nil shouldPrefetchProducts:nil];
  [engine action:nil shouldSilentlyUpdateProducts:nil];
  [engine commandRunnerForAction:nil];
  [engine action:nil shouldUpdateProducts:nil];
  [engine action:nil starting:nil];
  [engine action:nil finished:nil wasSuccess:NO wantsReboot:NO];

  NSArray *expect = [NSArray arrayWithObjects:
                     @"engine:shouldPrefetchProducts:",
                     @"engine:shouldSilentlyUpdateProducts:",
                     @"commandRunnerForEngine:",
                     @"engine:shouldUpdateProducts:",
                     @"engine:starting:",
                     @"engine:finished:wasSuccess:wantsReboot:",
                     nil];

  STAssertEqualObjects([tracker methods], expect, nil);

  // Make sure that if the delegate does not respond to the
  // commandRunnerForEngine: selector, we get back a default
  // command runner.
  engine = [KSUpdateEngine engineWithDelegate:nil];
  id<KSCommandRunner> runner = [engine commandRunnerForAction:nil];
  STAssertNotNil(runner, nil);
}

- (void)testFailedUpdate {
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath_];
  STAssertNotNil(store, nil);
  STAssertTrue([[store tickets] count] == 0, nil);

  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];
  KSTicket *t = [KSTicket ticketWithProductID:@"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST"
                                      version:@"1.0"
                             existenceChecker:xc
                                    serverURL:serverFailurePlistURL_];

  STAssertTrue([store storeTicket:t], nil);

  UpdateEngineDelegate *delegate = [[[UpdateEngineDelegate alloc] init] autorelease];
  KSUpdateEngine *engine = nil;
  engine = [KSUpdateEngine engineWithTicketStore:store delegate:delegate];
  STAssertNotNil(engine, nil);

  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:@"/dev/null"
                                                        autoSynchronize:NO];
  STAssertTrue([stats count] == 0, nil);
  [engine setStatsCollection:stats];

  [engine updateAllProducts];

  [self loopUntilDone:delegate];

  STAssertFalse([engine isUpdating], nil);

  // Make sure the update failed
  STAssertTrue([delegate updateFailed], nil);
  // But UpdateEngine as a whole should have succeeded
  STAssertFalse([delegate engineFailed], nil);

  STAssertTrue([stats count] > 0, nil);
  [engine setStatsCollection:nil];

  // Verify that a few stats are present and accurate.
  STAssertEqualObjects([stats numberForStat:kStatChecks], [NSNumber numberWithInt:1], nil);
  STAssertEqualObjects([stats numberForStat:kStatDownloads], [NSNumber numberWithInt:1], nil);
  STAssertEqualObjects([stats numberForStat:kStatTickets], [NSNumber numberWithInt:1], nil);
  STAssertEqualObjects([stats numberForStat:kStatValidTickets], [NSNumber numberWithInt:1], nil);

  NSString *statKey = KSMakeProductStatKey(@"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST", kStatInstallRC);
  STAssertEqualObjects([stats numberForStat:statKey], [NSNumber numberWithInt:11], nil);
}

- (void)testUpdateFromGoodURL {
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath_];
  STAssertNotNil(store, nil);

  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];
  KSTicket *t = [KSTicket ticketWithProductID:@"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST"
                                      version:@"1.0"
                             existenceChecker:xc
                                    serverURL:serverSuccessPlistURL_];
  STAssertTrue([store storeTicket:t], nil);

  UpdateEngineDelegate *delegate = [[[UpdateEngineDelegate alloc] init] autorelease];
  KSUpdateEngine *engine = nil;
  engine = [KSUpdateEngine engineWithTicketStore:store delegate:delegate];
  STAssertNotNil(engine, nil);

  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:@"/dev/null"
                                                        autoSynchronize:NO];
  [engine setStatsCollection:stats];

  [engine updateAllProducts];

  [self loopUntilDone:delegate];

  STAssertFalse([engine isUpdating], nil);

  // Make sure the update succeeded
  STAssertFalse([delegate updateFailed], nil);
  // And that UpdateEngine as a whole succeeded
  STAssertFalse([delegate engineFailed], nil);

  // And that we got legit progress:
  NSArray *progress = [delegate progressArray];
  STAssertTrue([progress count] >= 2, nil);

  // No guarantees about these two but they just make sense
  STAssertTrue([[progress objectAtIndex:0]
                 isEqual:[NSNumber numberWithFloat:0.0]], nil);
  STAssertTrue([[progress lastObject]
                 isEqual:[NSNumber numberWithFloat:1.0]], nil);

  // Make sure progress never goes backwards
  float f = 0.0;
  NSEnumerator *aenum = [progress objectEnumerator];
  NSNumber *num = nil;
  while ((num = [aenum nextObject]) != nil) {
    STAssertTrue([num floatValue] >= f, nil);
    f = [num floatValue];
  }


  STAssertTrue([stats count] > 0, nil);
  [engine setStatsCollection:nil];

  // Verify that a few stats are present and accurate.
  STAssertEqualObjects([stats numberForStat:kStatChecks], [NSNumber numberWithInt:1], nil);
  STAssertEqualObjects([stats numberForStat:kStatDownloads], [NSNumber numberWithInt:1], nil);
  STAssertEqualObjects([stats numberForStat:kStatTickets], [NSNumber numberWithInt:1], nil);
  STAssertEqualObjects([stats numberForStat:kStatValidTickets], [NSNumber numberWithInt:1], nil);

  NSString *statKey = KSMakeProductStatKey(@"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST", kStatInstallRC);
  STAssertEqualObjects([stats numberForStat:statKey], [NSNumber numberWithInt:0], nil);

  //
  // Make sure we can update a single product ID
  //
  delegate = [[[UpdateEngineDelegate alloc] init] autorelease];
  [engine setDelegate:delegate];

  [engine updateProductWithProductID:@"COM.GOOGLE.UPDATEENGINE.KSUPDATEENGINE_TEST"];
  [self loopUntilDone:delegate];

  STAssertFalse([engine isUpdating], nil);

  // Make sure the update succeeded
  STAssertFalse([delegate updateFailed], nil);
  // And that UpdateEngine as a whole succeeded
  STAssertFalse([delegate engineFailed], nil);
}

- (void)testFailedCheck {
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath_];
  STAssertNotNil(store, nil);

  //
  // First test using 1 ticket with an unreachable URL
  //

  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];
  KSTicket *t = [KSTicket ticketWithProductID:@"com.google.foo"
                                      version:@"1.0"
                             existenceChecker:xc
                                    serverURL:[NSURL URLWithString:@"https://asdfasdf.tools.google.com"]];

  STAssertTrue([store storeTicket:t], nil);

  UpdateEngineDelegate *delegate = [[[UpdateEngineDelegate alloc] init] autorelease];
  KSUpdateEngine *engine = nil;
  engine = [KSUpdateEngine engineWithTicketStore:store delegate:delegate];
  STAssertNotNil(engine, nil);

  [engine updateAllProducts];
  [self loopUntilDone:delegate];

  STAssertFalse([engine isUpdating], nil);

  // But UpdateEngine as a whole should have succeeded
  STAssertTrue([delegate engineFailed], nil);


  //
  // Second, test with multiple tickets with an unreachable URL
  //

  t = [KSTicket ticketWithProductID:@"com.google.foo1"
                            version:@"1.0"
                   existenceChecker:xc
                          serverURL:[NSURL URLWithString:@"https://zas4zf4.tools.google.com"]];

  STAssertTrue([store storeTicket:t], nil);

  delegate = [[[UpdateEngineDelegate alloc] init] autorelease];
  engine = [KSUpdateEngine engineWithTicketStore:store delegate:delegate];
  STAssertNotNil(engine, nil);

  [engine updateAllProducts];
  [self loopUntilDone:delegate];

  STAssertFalse([engine isUpdating], nil);

  // But UpdateEngine as a whole should have succeeded
  STAssertTrue([delegate engineFailed], nil);

  //
  // Third, add one ticket with a GOOD URL, and the check should succeed.
  //

  t = [KSTicket ticketWithProductID:@"com.google.foo2"
                            version:@"1.0"
                   existenceChecker:xc
                          serverURL:[NSURL URLWithString:@"file:///etc/passwd"]];

  STAssertTrue([store storeTicket:t], nil);

  delegate = [[[UpdateEngineDelegate alloc] init] autorelease];
  engine = [KSUpdateEngine engineWithTicketStore:store delegate:delegate];
  STAssertNotNil(engine, nil);

  [engine updateAllProducts];
  [self loopUntilDone:delegate];

  STAssertFalse([engine isUpdating], nil);

  //
  // Fourth, try updating a product with no corresponding ticket.
  //
  [engine updateProductWithProductID:@"lotus blossom"];

  // But UpdateEngine as a whole should have succeeded
  STAssertFalse([delegate engineFailed], nil);  // <-- This is the diff
}

- (void)testWithBadDelegate {
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath_];
  STAssertNotNil(store, nil);
  KSExistenceChecker *xc = [KSPathExistenceChecker checkerWithPath:@"/"];
  // Make sure there's at least one ticket, so that the statsForProductID:
  // delegate will be called.
  KSTicket *t;
  t = [KSTicket ticketWithProductID:@"com.google.foo3"
                            version:@"1.0"
                   existenceChecker:xc
                          serverURL:[NSURL URLWithString:@"file:///etc/passwd"]];
  STAssertTrue([store storeTicket:t], nil);

  BadDelegate *delegate = [[[BadDelegate alloc] init] autorelease];
  KSUpdateEngine *engine =
    [KSUpdateEngine engineWithTicketStore:store delegate:delegate];
  STAssertNotNil(engine, nil);

  [engine processingStarted:nil];
  [engine processingStopped:nil];
  [engine updateAllProducts];

  // Call all the delegate methods.

  NSArray *products = [NSArray array];

  STAssertEqualObjects([engine action:nil shouldPrefetchProducts:products],
                       products, nil);

  STAssertEqualObjects([engine action:nil shouldSilentlyUpdateProducts:products],
                       products, nil);

  STAssertNil([engine commandRunnerForAction:nil], nil);

  STAssertEqualObjects([engine action:nil shouldUpdateProducts:nil],
                       nil, nil);

  // void returns
  [engine action:nil starting:nil];
  [engine action:nil finished:nil wasSuccess:NO wantsReboot:NO];
  [engine action:nil running:nil progress:nil];

  // Simply make sure we got this far w/o letting an exception through
  STAssertTrue(YES, nil);
}

- (void)testParams {
  KSTicketStore *store = [KSTicketStore ticketStoreWithPath:storePath_];
  KSUpdateEngine *engine = [KSUpdateEngine engineWithTicketStore:store
                                                        delegate:nil];
  NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"oop", @"ack",
                                       @"bill th", @"e cat", nil];
  [engine setParams:params];
  NSDictionary *engineParams = [engine valueForKey:@"params_"];
  STAssertTrue([params isEqualToDictionary:engineParams], nil);
}

@end

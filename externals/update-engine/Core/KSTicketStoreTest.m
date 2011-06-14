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

#import "KSTicketStoreTest.h"
#import "KSTicketStore.h"
#import "KSTicket.h"
#import "KSExistenceChecker.h"
#import "KSUUID.h"
#import "GTMLogger.h"


static KSTicket *GenerateTicketWithXC(KSExistenceChecker *xc) {
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  KSTicket *t = [KSTicket ticketWithProductID:[KSUUID uuidString]
                                 version:@"1.1"
                        existenceChecker:xc
                               serverURL:url];
  return t;
}

static KSTicket *GenerateTicket(void) {
  return GenerateTicketWithXC([KSExistenceChecker falseChecker]);
}

static KSTicket *GenerateTicketWithXCPath(NSString *path) {
  return GenerateTicketWithXC([KSPathExistenceChecker checkerWithPath:path]);
}


// This class simply houses a -threadMain: method for testing concurrently
// accessing a ticket store. See the -threadMain: comments for more details.
//
// This class is only used in the -testLocking unit test method below.
@interface Threader : NSObject 
- (void)threadMain:(id)info;
@end

static volatile int gFailedThreaders = 0;  // The total number of threads who failed.
static volatile int gStoppedThreads = 0;
static NSString *kHugeLock = @"lock";

@implementation Threader
// This method is called in a separate thread and it's passed an NSDictionary
// with a ticket store ("store") and an array of tickets ("tickets") that
// *should be* in the store at all times. All we do is loop through N times and
// re-add the tickets that should already be in the store to the store again. 
// Then we read the tickets back out of the store to guarantee that the store
// has what we expect.
//
// The point is that the invariant of this test is that the |store| *always* has
// the tickets that are specified in the |tickets| array. Even though multiple
// threads are modifying the store (albeit, with the same tickets), each one
// always gets a consistent snapshot.
- (void)threadMain:(id)info {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  KSTicketStore *store = [info objectForKey:@"store"];
  NSArray *tickets = [info objectForKey:@"tickets"];
  
  // We actually pack the tickets into a set because we don't care about order
  NSSet *ticketSet = [NSSet setWithArray:tickets];
  
  for (int i = 0; i < 100; ++i) {
    //
    // Store all the |tickets| into the |store| (again)
    //
    KSTicket *t = nil;
    NSEnumerator *ticketEnumerator = [tickets objectEnumerator];
    while ((t = [ticketEnumerator nextObject])) {
      if (![store storeTicket:t])
        GTMLoggerError(@"!!!!!!!! Failed to store ticket %@", t);  // COV_NF_LINE
    }
    
    //
    // Read tickets back out and make sure it's all consistent
    //
    NSArray *allTickets = [store tickets];
    NSSet *allTicketSet = [NSSet setWithArray:allTickets];
    if (![ticketSet isEqual:allTicketSet]) {
      // COV_NF_START
      GTMLoggerError(@"failed to read tickets out of store. Expected %@, "
                     @"but got %@", tickets, allTickets);
      @synchronized (kHugeLock) {
        ++gFailedThreaders;  // Count our failed threader
      }
      // COV_NF_END
    }
  }
  
  [pool release];
  @synchronized (kHugeLock) {
    ++gStoppedThreads;
  }
}
@end

static NSString *const kTicketStorePath = @"/tmp/KSTicketStoreTest.ticketstore";

@implementation KSTicketStoreTest

- (void)setUp {
  // Reset these to 0 because if anything subclasses us these statics may no
  // longer be 0 initialized.
  gStoppedThreads = 0;
  gFailedThreaders = 0;

  // This ivar may not be nil if a subclass has overridden this method and 
  // has already assigned to store_ before calling this method via super.
  if (store_ == nil) {
    [[NSFileManager defaultManager] removeFileAtPath:kTicketStorePath handler:nil];
    NSString *lock = [kTicketStorePath stringByAppendingPathExtension:@"lock"];
    [[NSFileManager defaultManager] removeFileAtPath:lock handler:nil];
    store_ = [[KSTicketStore alloc] initWithPath:kTicketStorePath];
  }
  // Basic sanity tests
  STAssertNotNil(store_, nil);
  STAssertNotNil([store_ path], nil);
  STAssertNotNil([store_ tickets], nil);
  STAssertEquals(0, [store_ ticketCount], nil);
  STAssertTrue([[store_ description] length] > 1, nil);
}

- (void)tearDown {
  NSString *path = [store_ path];
  STAssertNotNil(path, nil);
  [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
  NSString *lock = [path stringByAppendingPathExtension:@"lock"];
  [[NSFileManager defaultManager] removeFileAtPath:lock handler:nil];
  [store_ release];
  store_ = nil;
}

- (void)testTicketStore {
  KSTicketStore *ts = [[[KSTicketStore alloc] init] autorelease];
  STAssertNil(ts, nil);
    
  KSTicket *t1 = GenerateTicket();
  STAssertNotNil(t1, nil);
  
  STAssertEquals([store_ ticketCount], 0, nil);
  STAssertTrue([store_ storeTicket:t1], nil);
  STAssertEquals(1, [store_ ticketCount], nil);

  STAssertTrue([store_ deleteTicket:t1], nil);
  STAssertEquals(0, [store_ ticketCount], nil);
  STAssertNotNil([store_ tickets], nil);

  // Re-adding the same ticket should not increase the ticket count because
  // tickets should be unique.
  for (int i = 1; i < 5; i++) {
    STAssertTrue([store_ storeTicket:t1], nil);
    STAssertEquals(1, [store_ ticketCount], nil);
  }

  // Adding new tickets should increase the ticket count.
  for (int i = 1; i < 5; i++) {
    KSTicket *newTicket = GenerateTicket();
    STAssertTrue([store_ storeTicket:newTicket], nil);
    STAssertEquals(1 + i, [store_ ticketCount], nil);
  }
  STAssertEquals(5, [store_ ticketCount], nil);

  // Now, remove our orginal ticket, and see the count drop back down.
  STAssertTrue([store_ deleteTicket:t1], nil);
  STAssertEquals(4, [store_ ticketCount], nil);

}

- (void)testTicketRetrieval {
  KSTicket *t1 = GenerateTicket();
  KSTicket *t2 = GenerateTicket();
  KSTicket *t3 = GenerateTicket();

  STAssertNotNil(t1, nil);
  STAssertNotNil(t2, nil);
  STAssertNotNil(t3, nil);

  STAssertTrue([store_ storeTicket:t1], nil);
  STAssertEquals(1, [store_ ticketCount], nil);

  STAssertTrue([store_ storeTicket:t2], nil);
  STAssertEquals(2, [store_ ticketCount], nil);

  STAssertTrue([store_ storeTicket:t3], nil);
  STAssertEquals(3, [store_ ticketCount], nil);

  KSTicket *found = nil;

  found = [store_ ticketForProductID:[t1 productID]];
  STAssertEqualObjects(t1, found, nil);

  found = [store_ ticketForProductID:[t2 productID]];
  STAssertEqualObjects(t2, found, nil);

  found = [store_ ticketForProductID:[t3 productID]];
  STAssertEqualObjects(t3, found, nil);
  
  STAssertTrue([store_ deleteTicketForProductID:[t3 productID]], nil);
  found = [store_ ticketForProductID:[t3 productID]];
  STAssertNil(found, nil);
  
  // Test a PRODUCTID that is not in the ticket store
  KSTicket *t4 = GenerateTicket();
  found = [store_ ticketForProductID:[t4 productID]];
  STAssertNil(found, nil);
}

- (void)testUniqueness {
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
  KSTicket *t1 = [KSTicket ticketWithProductID:@"{PRODUCTID}"
                                  version:@"1.1"
                         existenceChecker:xc
                                serverURL:url];

  STAssertNotNil(t1, nil);
  STAssertEquals(0, [store_ ticketCount], nil);

  // Re-adding the same ticket should not increase the ticket count because
  // tickets should be unique.
  for (int i = 1; i < 5; i++) {
    STAssertTrue([store_ storeTicket:t1], nil);
    STAssertEquals(1, [store_ ticketCount], nil);
  }

  KSTicket *t2 = nil;

  t2 = [KSTicket ticketWithProductID:@"{productid}"
                          version:@"1.1"
               existenceChecker:xc
                      serverURL:url];
  STAssertTrue([store_ storeTicket:t2], nil);
  STAssertEquals(1, [store_ ticketCount], nil);
  STAssertEqualObjects(t2, [store_ ticketForProductID:[t2 productID]], nil);

  t2 = [KSTicket ticketWithProductID:@"{pRoDUCtID}"
                        version:@"1.1!"
               existenceChecker:xc
                      serverURL:url];
  STAssertTrue([store_ storeTicket:t2], nil);
  STAssertEquals(1, [store_ ticketCount], nil);
  STAssertEqualObjects(t2, [store_ ticketForProductID:[t2 productID]], nil);

  t2 = [KSTicket ticketWithProductID:@"{productID}"
                        version:@"1.1!"
               existenceChecker:xc
                      serverURL:url];
  STAssertTrue([store_ storeTicket:t2], nil);
  STAssertEquals(1, [store_ ticketCount], nil);
  STAssertEqualObjects(t2, [store_ ticketForProductID:[t2 productID]], nil);

  // Now that the PRODUCTID is changing, the ticket count should actually increase
  t2 = [KSTicket ticketWithProductID:@"{PRODUCTID}!"
                        version:@"1.1!"
               existenceChecker:xc
                      serverURL:url];
  STAssertTrue([store_ storeTicket:t2], nil);
  STAssertEquals(2, [store_ ticketCount], nil);
}

- (void)testEncodeDecode {
  STAssertTrue([store_ storeTicket:GenerateTicket()], nil);
  STAssertTrue([store_ storeTicket:GenerateTicket()], nil);
  STAssertTrue([store_ storeTicket:GenerateTicketWithXCPath(@"/tmp")], nil);
  STAssertTrue([store_ storeTicket:GenerateTicketWithXCPath(@"/Foo/Bar")], nil);

  // store2 is now a new ticket store which originated from disk.
  KSTicketStore *store2 = [KSTicketStore ticketStoreWithPath:[store_ path]];
  STAssertNotNil(store2, nil);

  // compare store_ with store2
  STAssertEquals([store_ ticketCount], [store2 ticketCount], nil);
  NSArray *ticketArray = [store_ tickets];
  NSEnumerator *tenum = [ticketArray objectEnumerator];
  KSTicket *ticket1 = nil; // from store1
  while ((ticket1 = [tenum nextObject])) {
    KSTicket *ticket2 = [store2 ticketForProductID:[ticket1 productID]];  // from store2
    STAssertNotNil(ticket2, nil);
    STAssertEqualObjects(ticket1, ticket2, nil);
  }
}

- (void)testQuerying {
  NSURL *url1 = [NSURL URLWithString:@"http://blah"];
  NSURL *url2 = [NSURL URLWithString:@"http://quux"];
  
  KSTicket *t1 = [KSTicket ticketWithProductID:@"foo"
                                       version:@"1.0"
                              existenceChecker:[KSExistenceChecker falseChecker]
                                     serverURL:url1];
  KSTicket *t2 = [KSTicket ticketWithProductID:@"bar"
                                       version:@"2.0"
                              existenceChecker:[KSExistenceChecker falseChecker]
                                     serverURL:url1];
  KSTicket *t3 = [KSTicket ticketWithProductID:@"baz"
                                       version:@"3.0"
                              existenceChecker:[KSExistenceChecker falseChecker]
                                     serverURL:url2];
  
  STAssertNotNil(t1, nil);
  STAssertNotNil(t2, nil);
  STAssertNotNil(t3, nil);

  STAssertNil([[store_ tickets] ticketsByURL], nil);
  
  STAssertTrue([store_ storeTicket:t1], nil);
  STAssertTrue([store_ storeTicket:t2], nil);
  STAssertTrue([store_ storeTicket:t3], nil);
  
  NSDictionary *truth = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObjects:t1, t2, nil], url1,
                         [NSArray arrayWithObject:t3], url2, nil];
  
  NSDictionary *byURL = [[store_ tickets] ticketsByURL];
  STAssertNotNil(byURL, nil);
  
  STAssertEqualObjects(byURL, truth, nil);
}

- (void)testLocking {
  KSTicket *t1 = GenerateTicket();
  STAssertNotNil(t1, nil);
  
  KSTicket *t2 = GenerateTicket();
  STAssertNotNil(t2, nil);
  
  STAssertTrue([store_ storeTicket:t1], nil);
  STAssertTrue([store_ storeTicket:t2], nil);
  
  NSArray *tickets = [NSArray arrayWithObjects:t1, t2, nil];
  STAssertNotNil(tickets, nil);
  
  // Package up some parameters that we want to give to each NSThread
  NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                        tickets, @"tickets",
                        store_, @"store", nil];
  
  static const int kNumThreads = 10;
  
  // Create 10 NSThreads, give each one the |info| dictionary, and tell each
  // one to run their -threadMain:
  for (int i = 0; i < kNumThreads; ++i) {
    Threader *threader = [[[Threader alloc] init] autorelease];
    [NSThread detachNewThreadSelector:@selector(threadMain:)
                             toTarget:threader
                           withObject:info];
  }
  
  // Wait for threads to finish
  while (1) {
    NSDate *quick = [NSDate dateWithTimeIntervalSinceNow:0.2];
    [[NSRunLoop currentRunLoop] runUntilDate:quick]; 
    @synchronized (kHugeLock) {
      if (gStoppedThreads == kNumThreads) break;
    }
  }

  // This ensures that none of the threads failed to access the ticket store
  STAssertTrue(gFailedThreaders == 0, nil);
}

@end

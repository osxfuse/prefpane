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
#import "KSTicketStoreTest.h"
#import "KSMemoryTicketStore.h"


// Most test methods are inherited from KSTicketStoreTest. This class overrides
// setUp and tearDown to set the protected |store_| var to the correct subclass
// to be tested.
@interface KSMemoryTicketStoreTest : KSTicketStoreTest
// Override to do nothing because KSMemoryTicketStore instances do not serialize
// objects to disk at all, so encoding/decoding is never used (it defeats the 
// purpose of the class).
- (void)testEncodeDecode;
@end


@implementation KSMemoryTicketStoreTest

- (void)setUp {
  store_ = [[KSMemoryTicketStore alloc] initWithPath:nil];
  [super setUp];
}

- (void)tearDown {
  [store_ release];
  store_ = nil;
}

- (void)testInitialization {
  KSTicketStore *store = [[[KSMemoryTicketStore alloc] init] autorelease];
  STAssertNotNil(store, nil);
  
  store = [KSMemoryTicketStore ticketStoreWithPath:nil];
  STAssertNotNil(store, nil);
  
  store = [KSMemoryTicketStore ticketStoreWithPath:@"/tmp/foo"];
  STAssertNil(store, nil);
}

- (void)testEncodeDecode {
  // Override parent's imp to do nothing.
}

@end

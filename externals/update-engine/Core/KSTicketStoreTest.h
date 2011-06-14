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

@class KSTicketStore;

// Tests a KSTicketStore instance. This test case may be subclassed to enable
// testing of KSTicketStore subclasses. Subclasses should override -setUp and
// assign a value to the |store_| ivar, then call through to [super setUp].
// Subclasses should also override -tearDown to do any necessary cleanup.
// Subclasses do NOT need to call through to [super tearDown].
@interface KSTicketStoreTest : SenTestCase {
 @protected
  KSTicketStore *store_;
}

- (void)testTicketStore;
- (void)testTicketRetrieval;
- (void)testUniqueness;
- (void)testEncodeDecode;
- (void)testQuerying;
- (void)testLocking;

@end

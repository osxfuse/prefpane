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

#import <Foundation/Foundation.h>
#import "KSTicketStore.h"


// KSMemoryTicketStore
//
// This KSTicketStore subclass represents an in-memory, temporary ticket store
// that does not persist across invocations of the application. The tickets
// stored in this store are only stored as long as the KSMemoryTicketStore
// instance exists. This is simply a KSTicketStore that is backed by an
// in-memory NSDictionary rather than disk. The arg passed to -initWithPath:
// MUST be nil.
//
// Sample usage:
//
//   KSTicket *t = ...
//   KSTicketStore *ts = [[KSMemoryTicketStore alloc] init];
//   [ts storeTicket:t];        // [ts ticketCount] == 1
//   [ts storeDeleteTicket:t];  // [ts ticketCount] == 0
//   
@interface KSMemoryTicketStore : KSTicketStore {
 @private
  NSMutableDictionary *tickets_;
}

// No new methods added. See KSTicketStore.h for API.

@end

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

#import "KSMemoryTicketStore.h"
#import "KSTicket.h"


@implementation KSMemoryTicketStore

- (id)initWithPath:(NSString *)path {
  NSString *dummy = [NSString stringWithFormat:@"KSMemoryTicketStore-%p", self];
  if ((self = [super initWithPath:dummy])) {
    if (path != nil) {
      [self release];
      return nil;
    }
    tickets_ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [tickets_ release];
  [super dealloc];
}

- (NSArray *)tickets {
  NSArray *values = nil;
  @synchronized (tickets_) {
    values = [tickets_ allValues];
  }
  return values;
}

- (KSTicket *)ticketForProductID:(NSString *)productid {
  if (productid == nil) return nil;
  KSTicket *ticket = nil;
  @synchronized (tickets_) {
    ticket = [tickets_ objectForKey:[productid lowercaseString]];
  }
  return ticket;
}

- (BOOL)storeTicket:(KSTicket *)ticket {
  if (ticket == nil) return NO;  
  @synchronized (tickets_) {
    [tickets_ setObject:ticket forKey:[[ticket productID] lowercaseString]];
  }
  return YES;
}

- (BOOL)deleteTicket:(KSTicket *)ticket {
  if (ticket == nil) return NO;
  @synchronized (tickets_) {
    [tickets_ removeObjectForKey:[[ticket productID] lowercaseString]];
  }
  return YES;
}

@end

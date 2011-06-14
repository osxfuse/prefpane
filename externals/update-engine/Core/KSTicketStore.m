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

#import "KSTicketStore.h"
#import "KSTicket.h"
#import <fcntl.h>
#import <unistd.h>


// Implementation note: Tickets are stored internally in a dictionary
// keyed by each ticket's ProductID.  This means that no two tickets
// can have the same ProductID, which is exactly the behavior that we
// want.


@interface KSTicketStore (PrivateMethods)
- (NSMutableDictionary *)readTicketMap;
- (BOOL)writeTicketMap:(NSMutableDictionary *)ticketMap;
- (NSMutableDictionary *)atomicReadTicketMap;
- (BOOL)atomicStoreTicket:(KSTicket *)ticket;
- (BOOL)atomicDeleteTicket:(KSTicket *)ticket;
@end


@implementation KSTicketStore

+ (id)ticketStoreWithPath:(NSString *)path {
  return [[[self alloc] initWithPath:path] autorelease];
}

- (id)initWithPath:(NSString *)path {
  if ((self = [super init])) {
    path_ = [path copy];
    if (path_ == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)init {
  return [self initWithPath:nil];
}

- (void)dealloc {
  [path_ release];
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p path=%@>",
          [self class], self, path_];
}

- (NSString *)path {
  return path_;
}

- (int)ticketCount {
  return [[self tickets] count];
}

// We never want to return nil here. If we don't have any tickets, then we'll
// set an empty array of them, and return that empty array.
- (NSArray *)tickets {
  NSDictionary *map = [self atomicReadTicketMap];
  return map ? [map allValues] : [NSArray array];
}

- (KSTicket *)ticketForProductID:(NSString *)productid {
  if (productid == nil) return nil;
  productid = [productid lowercaseString];
  KSTicket *ticket = nil;
  NSEnumerator *ticketEnumerator = [[self tickets] objectEnumerator];
  while ((ticket = [ticketEnumerator nextObject])) {
    // Do case insensitive but case preserving comparison by lowercasing
    if ([productid isEqualToString:[[ticket productID] lowercaseString]])
      break;
  }
  return ticket;
}

- (BOOL)storeTicket:(KSTicket *)ticket {
  return [self atomicStoreTicket:ticket];
}

- (BOOL)deleteTicket:(KSTicket *)ticket {
  return [self atomicDeleteTicket:ticket];
}

- (BOOL)deleteTicketForProductID:(NSString *)productid {
  KSTicket *ticket = [self ticketForProductID:productid];
  return [self deleteTicket:ticket];
}

@end  // KSTicketStore


@implementation KSTicketStore (PrivateMethods)

- (NSMutableDictionary *)readTicketMap {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");
  NSData *data = [NSData dataWithContentsOfFile:path_];
  if ([data length] == 0) return nil;
  NSDictionary *map = nil;
  
  @try {
    map = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  // COV_NF_START
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception unarchiving ticket store at %@: %@",
                   path_, ex);
  }
  // COV_NF_END
  
  return [[map mutableCopy] autorelease];
}

- (BOOL)writeTicketMap:(NSMutableDictionary *)ticketMap {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");
  if (ticketMap == nil) return NO;
  BOOL ok = NO;
  
  @try {
    ok = [NSKeyedArchiver archiveRootObject:ticketMap toFile:path_];
  // COV_NF_START
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception archiving ticket map to %@: %@",
                   path_, ex);
  }
  // COV_NF_END
  
  return ok;
}

// Locking
//
// The next few "atomic" methods use these macros to lock the ticket store file
// at path_ before accessing it. We do this with a simple advisory lock. The 
// lock file itself will be |path_| with a file extension of ".lock".
//
// Also, we do this using macros to make clear the very simple nature of this
// locking mechanism: these locks are not recursive, and aren't smart enough to
// "NOP" if the process already has the lock. If we wrapped this logic up in a
// full-blown object, one may be led to think that the locking mechanism is much
// more sophisticated than it really is.
// 
// The LOCK_STORE macro simple opens the ticket store path_ with the O_EXLOCK
// flag set. If this fails, it returns NO. The UNLOCK_STORE() macro simply
// closes the fd. These two methods must be balanced, and there must be no code
// paths that could lead to a LOCK_STORE() being called w/o a corresponding 
// UNLOCK_STORE(). Note that since these locks are based on FDs, when the
// process exists (even if it crashes), the advisory locks will be released.
#define LOCK_STORE() \
  NSString *_lockPath_ = [path_ stringByAppendingPathExtension:@"lock"]; \
  int _oflags_ = O_CREAT | O_RDONLY | O_EXLOCK; \
  int _lockFD_ = open([_lockPath_ fileSystemRepresentation], _oflags_, 0444); \
  if (_lockFD_ < 0) return NO  // COV_NF_LINE

#define UNLOCK_STORE() \
  if (_lockFD_ >= 0) close(_lockFD_)

- (NSMutableDictionary *)atomicReadTicketMap {
  LOCK_STORE();
  NSMutableDictionary *map = [self readTicketMap];
  UNLOCK_STORE();
  return map;
}

// Takes the lock and adds |ticket| to the on-disk ticket store.
- (BOOL)atomicStoreTicket:(KSTicket *)ticket {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");
  if (ticket == nil) return NO;
  
  LOCK_STORE();
  
  NSMutableDictionary *map = [self readTicketMap];
  if (map == nil) map = [NSMutableDictionary dictionary];
  // Store in a case insensitive but case preserving manner
  [map setObject:ticket forKey:[[ticket productID] lowercaseString]];
  BOOL ok = [self writeTicketMap:map];
  
  UNLOCK_STORE();
  
  return ok;
}

// Takes the lock and deletes |ticket| from the on-disk ticket store.
- (BOOL)atomicDeleteTicket:(KSTicket *)ticket {
  _GTMDevAssert(path_ != nil, @"path_ must not be nil");
  if (ticket == nil) return NO;
  
  LOCK_STORE();
  
  NSMutableDictionary *map = [self readTicketMap];
  // Delete in a case insensitive manner
  [map removeObjectForKey:[[ticket productID] lowercaseString]];
  BOOL ok = [self writeTicketMap:map];
  
  UNLOCK_STORE();
  
  return ok;
}

@end  // PrivateMethods


@implementation NSArray (TicketRetrieving)

- (NSDictionary *)ticketsByURL {
  NSMutableDictionary *urlToTickets = [NSMutableDictionary dictionary];
  
  KSTicket *ticket = nil;
  NSEnumerator *ticketEnumerator = [self objectEnumerator];
  while ((ticket = [ticketEnumerator nextObject])) {
    // Return nil if we find an object in the array that's not a KSTicket
    if (![ticket isKindOfClass:[KSTicket class]]) {
      // COV_NF_START
      GTMLoggerError(@"%@ is not a KSTicket, returning nil", ticket);
      return nil;
      // COV_NF_END
    }
    NSURL *key = [ticket serverURL];
    NSMutableArray *tickets = [urlToTickets objectForKey:key];
    if (tickets == nil) tickets = [NSMutableArray array];
    [tickets addObject:ticket];
    [urlToTickets setObject:tickets forKey:key];
  }
  
  return [urlToTickets count] > 0 ? urlToTickets : nil;
}

@end  // TicketStoreQuerying


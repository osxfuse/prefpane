// Copyright 2009 Google Inc.
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

#import "KSTicketTestBase.h"
#import "KSExistenceChecker.h"

@interface KSTicketTestBase(PrivateMethods)
- (void)testWhichIsIntentionallyEmpty;
@end

@implementation KSTicketTestBase

- (void)setUp {
  fileURL_ = [[NSURL alloc] initWithString:@"file://foo"];
  httpURL_ =
    [[NSURL alloc] initWithString:@"https://www.google.com/dir1/file1"];
  size_ = 3;
  fileTickets_ = [[NSMutableArray alloc] initWithCapacity:size_];
  httpTickets_ = [[NSMutableArray alloc] initWithCapacity:size_];
  for (int x = 0; x < size_; x++) {
    [fileTickets_ addObject:[self ticketWithURL:fileURL_ count:x]];
    [httpTickets_ addObject:[self ticketWithURL:httpURL_ count:x]];
  }
  httpServer_ = [[KSOmahaServer serverWithURL:httpURL_] retain];
  STAssertNotNil(httpServer_, nil);
}

- (void)tearDown {
  [fileURL_ release];
  [httpURL_ release];
  [fileTickets_ release];
  [httpTickets_ release];
  [httpServer_ release];
}

- (void)testWhichIsIntentionallyEmpty {
  // intentionally empty
}

- (KSTicket *)ticketWithURL:(NSURL *)url
                      count:(int)count
                    tttoken:(NSString *)tttoken
               creationDate:(NSDate *)creationDate
                        tag:(NSString *)tag
                  brandPath:(NSString *)brandPath
                   brandKey:(NSString *)brandKey
                versionPath:(NSString *)versionPath
                 versionKey:(NSString *)versionKey
                    version:(NSString *)version {

  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  NSString *guid = [NSString stringWithFormat:@"{guid-%d}", count];
  if (!version) version = [NSString stringWithFormat:@"1.%d", count];
  NSMutableDictionary *args =
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
                         guid, KSTicketProductIDKey,
                         xc, KSTicketExistenceCheckerKey,
                         version, KSTicketVersionKey,
                         url, KSTicketServerURLKey,
                         nil];

  if (tttoken) [args setValue:tttoken forKey:KSTicketTrustedTesterTokenKey];
  if (creationDate) [args setValue:creationDate forKey:KSTicketCreationDateKey];
  if (tag) [args setValue:tag forKey:KSTicketTagKey];
  if (brandPath && brandKey) {
    [args setValue:brandPath
            forKey:KSTicketBrandPathKey];
    [args setValue:brandKey
            forKey:KSTicketBrandKeyKey];
  }
  [args setValue:version forKey:KSTicketVersionKey];
  if (versionPath && versionKey) {
    [args setValue:versionPath
            forKey:KSTicketVersionPathKey];
    [args setValue:versionKey
            forKey:KSTicketVersionKeyKey];
  }

  KSTicket *t = [KSTicket ticketWithParameters:args];
  return t;
}

- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count {
  return [self ticketWithURL:url
                       count:count
                     tttoken:nil
                creationDate:nil
                         tag:nil
                   brandPath:nil
                    brandKey:nil
                 versionPath:nil
                  versionKey:nil
                     version:nil];
}

- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                    tttoken:(NSString *)tttoken {
  return [self ticketWithURL:url
                       count:count
                     tttoken:tttoken
                creationDate:nil
                         tag:nil
                   brandPath:nil
                    brandKey:nil
                 versionPath:nil
                  versionKey:nil
                     version:nil];
}

- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
               creationDate:(NSDate *)creationDate {
  return [self ticketWithURL:url
                       count:count
                     tttoken:nil
                creationDate:creationDate
                         tag:nil
                   brandPath:nil
                    brandKey:nil
                 versionPath:nil
                  versionKey:nil
                     version:nil];
}

- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                        tag:(NSString *)tag {
  return [self ticketWithURL:url
                       count:count
                     tttoken:nil
                creationDate:nil
                         tag:tag
                   brandPath:nil
                    brandKey:nil
                 versionPath:nil
                  versionKey:nil
                     version:nil];
}

- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                  brandPath:(NSString *)brandPath
                   brandKey:(NSString *)brandKey {
  return [self ticketWithURL:url
                       count:count
                     tttoken:nil
                creationDate:nil
                         tag:nil
                   brandPath:brandPath
                    brandKey:brandKey
                 versionPath:nil
                  versionKey:nil
                     version:nil];
}

- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                versionPath:(NSString *)versionPath
                 versionKey:(NSString *)versionKey
                    version:(NSString *)version {
  return [self ticketWithURL:url
                       count:count
                     tttoken:nil
                creationDate:nil
                         tag:nil
                   brandPath:nil
                    brandKey:nil
                 versionPath:versionPath
                  versionKey:versionKey
                     version:version];
}

@end

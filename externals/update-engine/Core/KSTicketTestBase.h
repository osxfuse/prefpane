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

#import <SenTestingKit/SenTestingKit.h>
#import "KSOmahaServer.h"
#import "KSTicket.h"

// For many unit tests we'll need a group of tickets, some servers, etc.
// Here's a common base class for that.  Since we don't have MI in objc,
// this needs to derive from SenTestCase.  Finally, since it derives
// from SenTestCase, otest thinks it's a test, so I added an empty test
// to avoid confusion about the "zero unit tests run" message.
@interface KSTicketTestBase : SenTestCase {
  NSURL *fileURL_;
  NSURL *httpURL_;
  int size_;
  NSMutableArray *fileTickets_;
  NSMutableArray *httpTickets_;
  KSOmahaServer *httpServer_;
}

// Helper to create a KSTicket with the given |url| and |count|.
// |x| is used to make the productID/version unique.
- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count;

// Helper to make a ticket with a given |url| and |count|, and extra
// bit of information.
- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                    tttoken:(NSString *)tttoken;
- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
               creationDate:(NSDate *)creationDate;
- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                        tag:(NSString *)tag;
- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                  brandPath:(NSString *)brandPath
                   brandKey:(NSString *)brandKey;
- (KSTicket *)ticketWithURL:(NSURL *)url count:(int)count
                versionPath:(NSString *)versionPath
                 versionKey:(NSString *)versionKey
                    version:(NSString *)version;

// Designated enticketizer: Set a bunch of ticket knobs at one time.
- (KSTicket *)ticketWithURL:(NSURL *)url
                      count:(int)count
                    tttoken:(NSString *)tttoken
               creationDate:(NSDate *)creationDate
                        tag:(NSString *)tag
                  brandPath:(NSString *)brandPath
                   brandKey:(NSString *)brandKey
                versionPath:(NSString *)versionPath
                 versionKey:(NSString *)versionKey
                    version:(NSString *)version;
@end

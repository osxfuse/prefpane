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
#import "KSPlistServer.h"
#import "KSUpdateInfo.h"
#import "KSTicket.h"
#import "KSExistenceChecker.h"


@interface KSPlistServerTest : SenTestCase {
 @private
  KSPlistServer *server_;
  NSArray *tickets_;
}
@end


//
// Static plist strings
//
// The easiest way to get these plist strings in here is to write them in a 
// regular file, then paste the output of the following command:
//
//   $ cat rule.plist | sed 's/"/\\"/g' | sed -E 's/^(.*)$/@"\1"/g'
//

//
// ====== 1 Rule ======
//

static NSString *const kPlist1Rule_1 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_2 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_3 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND BLAHBLAHBLAH </string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_4 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.DoesNotExist</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_5 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
// ... truncated XML
;

static NSString *const kPlist1Rule_6 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
// Missing hash
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_7 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <integer>123456</integer>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_8 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
// No rules
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_9 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
// Empty plist
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_10 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
// Missing ProductID
@"      <key>Predicate</key>"
@"      <string>Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlist1Rule_11 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>Foo.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/</string>"
@"      <key>Hash</key>"
@"      <string>somehash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

//
// ====== Multiple Rules ======
//

static NSString *const kPlistNRules_1 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/foo</string>"
@"      <key>Hash</key>"
@"      <string>foohash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Bar</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/bar</string>"
@"      <key>Hash</key>"
@"      <string>barhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Baz</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/baz</string>"
@"      <key>Hash</key>"
@"      <string>bazhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlistNRules_2 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/foo</string>"
@"      <key>Hash</key>"
@"      <string>foohash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Bar</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/bar</string>"
@"      <key>Hash</key>"
@"      <string>barhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Baz</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/baz</string>"
@"      <key>Hash</key>"
@"      <string>bazhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlistNRules_3 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/foo</string>"
@"      <key>Hash</key>"
@"      <string>foohash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Bar</string>"
@"      <key>Predicate</key>"
@"      <string>BLAHHHHHHHHHHH INVALID PREDICATE FORMAT</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/bar</string>"
@"      <key>Hash</key>"
@"      <string>barhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Baz</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.1'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/baz</string>"
@"      <key>Hash</key>"
@"      <string>bazhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

static NSString *const kPlistNRules_4 = 
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"  <key>Rules</key>"
@"  <array>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Foo</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/foo</string>"
@"      <key>Hash</key>"
@"      <string>foohash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Bar</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/bar</string>"
@"      <key>Hash</key>"
@"      <string>barhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"    <dict>"
@"      <key>ProductID</key>"
@"      <string>com.google.Baz</string>"
@"      <key>Predicate</key>"
@"      <string>SystemVersion.ProductVersion beginswith '10.' AND Ticket.version == '1.0'</string>"
@"      <key>Codebase</key>"
@"      <string>https://www.google.com/engine/baz</string>"
@"      <key>Hash</key>"
@"      <string>bazhash=</string>"
@"      <key>Size</key>"
@"      <string>123456</string>"
@"    </dict>"
@"  </array>"
@"</dict>"
@"</plist>"
;

@implementation KSPlistServerTest

// Simple helper function to make sure a KSUpdateInfo contains the correct info
- (void)assertUpdateInfo:(KSUpdateInfo *)ui
        matchesProductID:(NSString *)productID
                    hash:(NSString *)hash
                    size:(int)size
                     url:(NSString *)url {
  STAssertEqualObjects([ui productID], productID, nil);
  STAssertEqualObjects([ui codeHash], hash, nil);
  STAssertEqualObjects([ui codeSize], [NSNumber numberWithInt:size], nil);
  STAssertEqualObjects([ui codebaseURL], [NSURL URLWithString:url], nil);
}


- (void)setUp {
  NSURL *url = [NSURL URLWithString:@"https://engine.google.com"];
  server_ = [[KSPlistServer alloc] initWithURL:url];
  STAssertNotNil(server_, nil);
  
  KSExistenceChecker *xc = [KSExistenceChecker falseChecker];
  KSTicket *t1 = [KSTicket ticketWithProductID:@"com.google.Foo"
                                       version:@"1.1"
                              existenceChecker:xc
                                     serverURL:url];
  KSTicket *t2 = [KSTicket ticketWithProductID:@"com.google.Bar"
                                       version:@"1.1"
                              existenceChecker:xc
                                     serverURL:url];
  KSTicket *t3 = [KSTicket ticketWithProductID:@"com.google.Baz"
                                       version:@"1.1"
                              existenceChecker:xc
                                     serverURL:url];
  
  tickets_ = [[NSArray alloc] initWithObjects:t1, t2, t3, nil];
  STAssertNotNil(tickets_, nil);
}

- (void)tearDown {
  [server_ release];
  [tickets_ release];
}

- (void)testCreation {
  KSPlistServer *server = [[KSPlistServer alloc] init];
  STAssertNil(server, nil);
  
  server = [KSPlistServer serverWithURL:nil];
  STAssertNil(server, nil);
  
  NSURL *url = [NSURL URLWithString:@"http://non-ssl.google.com"];
  server = [KSPlistServer serverWithURL:url];
  STAssertNotNil(server, nil);
  
  url = [NSURL URLWithString:@"https://engine.google.com"];
  server = [KSPlistServer serverWithURL:url];
  STAssertNotNil(server, nil);
}

- (void)testRequests {
  // Make sure we always get a valid array with exactly one object (request) in
  // it, regardless of the tickets that we pass.
  NSArray *requests = [server_ requestsForTickets:nil];
  STAssertNotNil(requests, nil);
  STAssertEquals([requests count], 1U, nil);
  STAssertEqualObjects([server_ tickets], nil, nil);
  
  requests = [server_ requestsForTickets:[NSArray array]];
  STAssertNotNil(requests, nil);
  STAssertEquals([requests count], 1U, nil);
  STAssertEqualObjects([server_ tickets], [NSArray array], nil);
  
  requests = [server_ requestsForTickets:(NSArray *)@"not nil"];
  STAssertNotNil(requests, nil);
  STAssertEquals([requests count], 1U, nil);
  STAssertEqualObjects([server_ tickets], @"not nil", nil);
}

- (void)testUpdateInfosForResponsesSingleRule {
  // Need to call this so the KSPlistServer can get our list of tickets
  [server_ requestsForTickets:tickets_];
  
  // Make sure passing nil data returns nil
  STAssertNil([server_ updateInfosForResponse:nil data:nil outOfBandData:NULL],
              nil);
  
  // *** kPlist1Rule_1 ***
  // Expect: 1 update
  NSArray *updateInfos = nil;
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_1 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  
  STAssertNotNil(updateInfos, nil);
  STAssertEquals([updateInfos count], 1U, nil);
  
  // Make sure the one returned KSUpdateInfo is OK
  KSUpdateInfo *ui = [updateInfos lastObject];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Foo"
                    hash:@"somehash="
                    size:123456
                     url:@"https://www.google.com/engine/"];
  
  // *** kPlist1Rule_2 ***
  // Expect: No updates (due to predicate's ticket version)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_2 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_3 ***
  // Expect: No updates (due to invalid predicate)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_3 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_4 ***
  // Expect: No updates (due to unmatched product ID)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_4 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_5 ***
  // Expect: No updates (due to badly formed XML)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_5 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_6 ***
  // Expect: No updates (due to missing code hash)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_6 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_7 ***
  // Expect: 1 update (w/ the size specified as an integer)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_7 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNotNil(updateInfos, nil);
  ui = [updateInfos lastObject];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Foo"
                    hash:@"somehash="
                    size:123456
                     url:@"https://www.google.com/engine/"];
  
  // *** kPlist1Rule_8 ***
  // Expect: No updates (no rules)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_8 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_9 ***
  // Expect: No updates (empty plist)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_9 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_10 ***
  // Expect: No updates (empty plist)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_10 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
  
  // *** kPlist1Rule_11 ***
  // Expect: No updates (empty plist)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlist1Rule_11 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
}

- (void)testUpdateInfosForResponsesMultipleRules {
  // Need to call this so the KSPlistServer can get our list of tickets
  [server_ requestsForTickets:tickets_];
  
  // *** kPlistNRules_1 ***
  // Expect: 3 updates
  NSArray *updateInfos = nil;
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlistNRules_1 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  
  STAssertNotNil(updateInfos, nil);
  STAssertEquals([updateInfos count], 3U, nil);
  
  // Make sure the one returned KSUpdateInfo is OK
  KSUpdateInfo *ui = [updateInfos objectAtIndex:0];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Foo"
                    hash:@"foohash="
                    size:123456
                     url:@"https://www.google.com/engine/foo"];
  ui = [updateInfos objectAtIndex:1];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Bar"
                    hash:@"barhash="
                    size:123456
                     url:@"https://www.google.com/engine/bar"];
  ui = [updateInfos objectAtIndex:2];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Baz"
                    hash:@"bazhash="
                    size:123456
                     url:@"https://www.google.com/engine/baz"];
  
  // *** kPlistNRules_2 ***
  // Expect: 1 Update (other predicates fail)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlistNRules_2 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNotNil(updateInfos, nil);
  STAssertEquals([updateInfos count], 1U, nil);
  ui = [updateInfos objectAtIndex:0];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Baz"
                    hash:@"bazhash="
                    size:123456
                     url:@"https://www.google.com/engine/baz"];
  
  // *** kPlistNRules_3 ***
  // Expect: 1 Update (despite the exception that will be thrown for rule 2)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlistNRules_3 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNotNil(updateInfos, nil);
  STAssertEquals([updateInfos count], 1U, nil);
  ui = [updateInfos objectAtIndex:0];
  [self assertUpdateInfo:ui
        matchesProductID:@"com.google.Baz"
                    hash:@"bazhash="
                    size:123456
                     url:@"https://www.google.com/engine/baz"];
  
  // *** kPlistNRules_4 ***
  // Expect: No Updates (All predicates fail)
  updateInfos = [server_ updateInfosForResponse:nil data:
                 [kPlistNRules_4 dataUsingEncoding:NSUTF8StringEncoding]
                                  outOfBandData:NULL];
  STAssertNil(updateInfos, nil);
}

- (void)testPrettyPrinting {
  // Note that the pretty printing doesn't require the data to be plist data.
  // The pretty printing simply converts the given data into a UTF-8 NSString.
  NSArray *expectedStrings = [NSArray arrayWithObjects:
                              @"",
                              @" ",
                              @"   ",
                              @"a",
                              @"abc",
                              @"a\nb\nc",
                              @"<foo>bar</foo>",
                              @"<foo>bar</bar>",  // invalid xml
                              nil];
  
  
  NSString *expectedString = nil;
  NSEnumerator *stringEnumerator = [expectedStrings objectEnumerator];
  while ((expectedString = [stringEnumerator nextObject])) {
    NSData *data = [expectedString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *pretty = [server_ prettyPrintResponse:nil data:data];
    STAssertEqualObjects(pretty, expectedString, nil);
  }
}

@end

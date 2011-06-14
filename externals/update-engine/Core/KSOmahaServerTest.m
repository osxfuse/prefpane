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
#import "KSClientActives.h"
#import "KSFrameworkStats.h"
#import "KSStatsCollection.h"
#import "KSTicketStore.h"
#import "KSTicketTestBase.h"
#import "KSUpdateEngine.h"
#import "KSUpdateEngineParameters.h"
#import "KSUpdateInfo.h"

#define DEFAULT_BRAND_CODE @"GGLG"


@interface KSOmahaServer (TestingFriends)
- (BOOL)isAllowedURL:(NSURL *)url;
@end

@interface KSOmahaServerTest : KSTicketTestBase {
  // Contents populated by -engine:serverData:forProductID:withKey:
  // delegate method.
  NSMutableDictionary *serverDataDict_;
}
// helper to xpath things and verify they exist.  If only one item is found,
// return it.  Else return the array of items.
- (id)findInDoc:(NSXMLDocument *)doc path:(NSString *)path count:(int)count;
// If possible, convert a server request into an XMLDocument.
- (NSXMLDocument *)documentFromRequest:(NSData *)request;
@end


/* Sample request:

<?xml version="1.0" encoding="UTF-8"?>
<o:gupdate xmlns:o="http://www.google.com/update2/request" version="UpdateEngine-0.1.2.0" protocol="2.0" ismachine="0"">
    <o:os version="MacOS" sp="10.5.2"></o:os>
    <o:app appid="com.google.UpdateEngine" version="0.1.3.237" lang="en-us" brand="GGLG" installage="37" tag="f00bage">
        <o:updatecheck></o:updatecheck>
        <o:ping r="1" a="-1></o:ping>
    </o:app>
    <o:app appid="com.google.Matchbook.App" version="0.1.1.0" lang="en-us" brand="GGLG" installage="23">
        <o:updatecheck></o:updatecheck>
    </o:app>
    <o:app appid="com.google.Something.Else" version="0.1.1.0" lang="en-us" brand="GGLG" installage="0">
        <o:updatecheck tttoken="seCRETtoken"/>
        <o:ping r="10"></o:ping>
    </o:app>
</o:gupdate>


Sample response (but not for the above request):

<?xml version="1.0" encoding="UTF-8"?>
<gupdate xmlns="http://www.google.com/update2/response" protocol="2.0">
    <app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" status="ok">
        <updatecheck codebase="http://tools.google.com/omaha_download/test.dmg" hash="vaQXjdS1P6VP31rkqe8YuzbNzvk=" needsadmin="true" size="5910016" status="ok"></updatecheck>
        <rlz status="ok"></rlz>
        <ping status="ok"></ping>
    </app>
</gupdate>
*/

@implementation KSOmahaServerTest

// Convenience method to give a date n-hours in the past.
- (NSDate *)hoursAgo:(int)hours {
  NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-60 * 60 * hours];
  return date;
}

- (id)findInDoc:(NSXMLDocument *)doc path:(NSString *)path count:(int)count {
  NSError *err = nil;
  NSArray *nodes = [doc nodesForXPath:path error:&err];
  STAssertNotNil(nodes, nil);
  STAssertNil(err, nil);
  STAssertEquals([nodes count], (unsigned)count, nil);
  if ([nodes count] == 1) {
    return [nodes objectAtIndex:0];
  } else {
    return nodes;
  }
}

- (NSXMLDocument *)documentFromRequest:(NSData *)request {
  // sanity check
  NSString *requestString = [[[NSString alloc] initWithData:request
                                               encoding:NSUTF8StringEncoding]
                              autorelease];
  STAssertTrue([requestString rangeOfString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"].location == 0, nil);
  NSError *error = nil;
  // now make a doc.
  NSXMLDocument *doc = [[[NSXMLDocument alloc]
                          initWithData:request
                          options:0
                          error:&error]
                         autorelease];
  STAssertNil(error, nil);
  STAssertNotNil(doc, nil);
  return doc;
}

// The goal here is to look for some items like the server would.
// I don't verify values because some will surely change (e.g. version)
- (void)findCommonItemsInDocument:(NSXMLDocument *)doc
                         appcount:(int)appcount
                     tttokenCount:(int)tttokenCount {
  [self findInDoc:doc path:@".//o:gupdate/@version" count:1];
  [self findInDoc:doc path:@".//o:gupdate/@protocol" count:1];
  [self findInDoc:doc path:@".//o:gupdate/@ismachine" count:1];
  [self findInDoc:doc path:@".//o:gupdate/o:os/@version" count:1];
  [self findInDoc:doc path:@".//o:gupdate/o:os/@sp" count:1];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@appid" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@version" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@brand" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/@installage" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/o:updatecheck" count:appcount];
  [self findInDoc:doc path:@".//o:gupdate/o:app/o:updatecheck/@tttoken"
            count:tttokenCount];
}

- (void)testCreation {
  NSArray *goodURLs =
    [NSArray arrayWithObjects:
     [NSURL URLWithString:@"https://blah.google.com"],
     [NSURL URLWithString:@"https://blah.google.com/foo/bar"],
     [NSURL URLWithString:@"https://blah.google.com"],
     [NSURL URLWithString:@"https://foo.blah.google.com"],
     [NSURL URLWithString:@"https://foo.bar.blah.google.com"],
     nil];

  NSArray *badURLs =
    [NSArray arrayWithObjects:
     [NSURL URLWithString:@"file:///tmp/oop/ack"],
     [NSURL URLWithString:@"http://www.google.com/foo/bar"],
     [NSURL URLWithString:@"http://google.com"],
     [NSURL URLWithString:@"http://foo.google.com"],
     [NSURL URLWithString:@"https://elvisgoogle.com"],
     [NSURL URLWithString:@"https://www.gooogle.com"],
     [NSURL URLWithString:@"https://foo.com"],
     [NSURL URLWithString:@"https://google.foo.com"],
     nil];

  NSArray *allowedSubdomains = [NSArray arrayWithObject:@".blah.google.com"];
  NSDictionary *params =
    [NSDictionary dictionaryWithObject:allowedSubdomains
                                forKey:kUpdateEngineAllowedSubdomains];
  NSURL *url = nil;
  NSEnumerator *urlEnumerator = nil;

  urlEnumerator = [goodURLs objectEnumerator];
  while ((url = [urlEnumerator nextObject])) {
    STAssertNotNil([KSOmahaServer serverWithURL:url params:params], nil);
  }

  // In DEBUG builds, make sure the bad URLs show up as "good" (i.e., not nil),
  // but in Release builds, the bad URLs should show up as "bad" (i.e., nil).
  urlEnumerator = [badURLs objectEnumerator];
  while ((url = [urlEnumerator nextObject])) {
#ifdef DEBUG
    STAssertNotNil([KSOmahaServer serverWithURL:url params:params], nil);
#else
    STAssertNil([KSOmahaServer serverWithURL:url params:params], nil);
#endif
  }
}

- (void)testSingleTicket {
  // one file ticket
  NSMutableArray *oneTicket = [NSMutableArray arrayWithCapacity:1];
  [oneTicket addObject:[httpTickets_ objectAtIndex:0]];
  NSArray *requests = [httpServer_ requestsForTickets:oneTicket];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // make sure we find 1 app
  [self findInDoc:doc path:@".//o:gupdate/o:app" count:1];
  NSXMLNode *n = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid" count:1];
  STAssertTrue([n isKindOfClass:[NSXMLNode class]], nil);
  STAssertTrue([[n stringValue] isEqualToString:[[oneTicket objectAtIndex:0]
                                                  productID]], nil);
  // basic check of a request
  [self findCommonItemsInDocument:doc appcount:1 tttokenCount:0];
}

- (void)testSeveralTickets {
  // (try to) send all 3 http tickets to the http server
  NSArray *requests = [httpServer_ requestsForTickets:httpTickets_];
  int ticketcount = [httpTickets_ count];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  NSArray *apps = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid"
                        count:ticketcount];
  STAssertNotNil(apps, nil);
  STAssertTrue([apps isKindOfClass:[NSArray class]], nil);
  STAssertTrue([apps count] == ticketcount, nil);
  int x;
  for (x = 0; x < ticketcount; x++) {
    STAssertTrue([[apps objectAtIndex:x] isKindOfClass:[NSXMLNode class]], nil);
  }
  // make sure we find all 3 apps in there
  for (x = 0; x < ticketcount; x++) {
    NSString *appToFind = [[httpTickets_ objectAtIndex:x] productID];
    BOOL found = NO;
    NSEnumerator *aenum = [apps objectEnumerator];
    id app = nil;
    while ((app = [aenum nextObject])) {
      if ([[app stringValue] isEqualToString:appToFind]) {
        found = YES;
        break;
      }
    }
    STAssertTrue(found == YES, nil);
  }
  // basic check of a request
  [self findCommonItemsInDocument:doc appcount:ticketcount tttokenCount:0];
}

- (void)testTTTokenInTicket {
  // 4 tickets, but only 2 have tttokens
  int size = 4;
  NSMutableArray *lottatickets = [NSMutableArray arrayWithCapacity:size];
  for (int x = 0; x < size; x++) {
    if (x % 2) {
      [lottatickets addObject:[self ticketWithURL:httpURL_ count:x]];
    } else {
      NSString *token = [NSString stringWithFormat:@"token-%d", x];
      [lottatickets addObject:[self ticketWithURL:httpURL_ count:x
                                          tttoken:token]];
    }
  }
  STAssertTrue([lottatickets count] == size, nil);
  NSArray *requests = [httpServer_ requestsForTickets:lottatickets];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // make sure the request has 4 of these:
  //  <o:app appid="{guid...}" ... > </o:app>
  NSArray *apps = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid"
                        count:size];
  STAssertNotNil(apps, nil);
  STAssertTrue([apps isKindOfClass:[NSArray class]], nil);
  STAssertTrue([apps count] == size, nil);

  // Make sure it only has 2 tttokens
  [self findCommonItemsInDocument:doc appcount:size
                     tttokenCount:(size >> 1)];
}

- (void)testAWholeLottaTickets {
  int size = 257;
  NSMutableArray *lottatickets = [NSMutableArray arrayWithCapacity:size];
  for (int x = 0; x < size; x++) {
    [lottatickets addObject:[self ticketWithURL:httpURL_ count:x]];
  }
  STAssertTrue([lottatickets count] == size, nil);
  NSArray *requests = [httpServer_ requestsForTickets:lottatickets];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // make sure the request has 257 of these:
  //  <o:app appid="{guid...}" ... > </o:app>
  NSArray *apps = [self findInDoc:doc path:@".//o:gupdate/o:app/@appid"
                        count:size];
  STAssertNotNil(apps, nil);
  STAssertTrue([apps isKindOfClass:[NSArray class]], nil);
  STAssertTrue([apps count] == size, nil);
}

- (void)testBadTickets {
  // no tickets --> no request!
  NSMutableArray *empty = [NSMutableArray array];
  STAssertNil([httpServer_ requestsForTickets:empty], nil);

  // send a file ticket to an http server
  NSMutableArray *oneFileTicket = [NSMutableArray arrayWithCapacity:1];
  [oneFileTicket addObject:[fileTickets_ objectAtIndex:1]];
  STAssertNil([httpServer_ requestsForTickets:oneFileTicket], nil);
}

static char *kBadResponseStrings[] = {
  "",  // empty
  "                                       ", // whitespace
  "blah blah", // bogus
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",  // bare minimum XML document
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> </gupdate>", // empty
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\">", // malformed XML (no terminating gupdate)
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\"></app> </gupdate>",  // incomplete
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\" status=\"ko\"></app> </gupdate>",  // bad status
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\" status=\"ok\"></app> </gupdate>",  // good status, no updatecheck node
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app status=\"ok\"><updatecheck codebase=\"\" hash=\"\" needsadmin=\"\" size=\"\" status=\"ok\"></updatecheck> </app> </gupdate>",  // updatecheck, no appid
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?> <gupdate xmlns=\"foo\"> <app appid=\"{guid}\" status=\"ok\"><updatecheck hash=\"\" needsadmin=\"\" size=\"\" status=\"ok\"></updatecheck> </app> </gupdate>",  // updatecheck, missing a required attribute for updatecheck
};

// KSOmahaServer ignores its first arg (a NSURLResponse).
- (void)testBadResponses {
  NSArray *results = nil;
  results = [httpServer_ updateInfosForResponse:nil
                                           data:nil
                                  outOfBandData:NULL];
  STAssertTrue([results count] == 0, nil);

  int strings = sizeof(kBadResponseStrings)/sizeof(char *);
  for (int x = 0; x < strings; x++) {
    NSData *data = [NSData dataWithBytes:kBadResponseStrings[x]
                                  length:strlen(kBadResponseStrings[x])];
    STAssertNotNil(data, nil);
    results = [httpServer_ updateInfosForResponse:nil
                                             data:data
                                    outOfBandData:NULL];
    STAssertTrue([results count] == 0, nil);
  }
}

- (void)testBadPrettyprint {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  NSData *data = [@"hargleblargle" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *prettyInPink = [server prettyPrintResponse:nil data:data];
  STAssertNil(prettyInPink, nil);
}

- (NSArray *)updateInfoForStr:(const char *)str {
  NSData *data = [NSData dataWithBytes:str length:strlen(str)];
  return [httpServer_ updateInfosForResponse:nil
                                        data:data
                               outOfBandData:NULL];
}

static char *kSingleResponseString =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"    <app appid=\"{8A69D345-D564-463C-AFF1-A69D9E530F96}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test.dmg\" hash=\"vaQXjdS1P6VP31rkqe8YuzbNzvk=\" needsadmin=\"true\" size=\"5910016\" status=\"ok\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"</gupdate>";

static char *kSingleResponseStringWithDaystart =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"   <daystart elapsed_seconds=\"300\" />"
"    <app appid=\"{8A69D345-D564-463C-AFF1-A69D9E530F96}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test.dmg\" hash=\"vaQXjdS1P6VP31rkqe8YuzbNzvk=\" needsadmin=\"true\" size=\"5910016\" status=\"ok\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"</gupdate>";

static char *kNoResponseStringWithDaystart =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"   <daystart elapsed_seconds=\"19283\" />"
"   <app appid=\"com.google.kipple\" status=\"ok\">"
"     <updatecheck status=\"noupdate\" />"
"   </app>"
"</gupdate>";

- (void)testSingleResponse {
  NSArray *updateInfos = [self updateInfoForStr:kSingleResponseString];
  STAssertEquals([updateInfos count], 1U, nil);
}

// Notice that the second app in this list has prompt="true" and
// requireReboot="true" set, and the second app has a localization
// expansion for the moreinfo URL, a localization bundle path,
// a display version, and a pony.
static char *kMultiResponseString =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"   <daystart elapsed_seconds=\"300\" />"
"    <app appid=\"{26EA52A6-C1F2-11DB-B91C-B0B155D89593}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test2.dmg\" hash=\"hcqiyPD01sWXVdYHNpWe4H2OBak=\" needsadmin=\"false\" size=\"1868800\" status=\"ok\" MoreInfo=\"http://google.com\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"    <app appid=\"{8A69D345-D564-463C-AFF1-A69D9E530F96}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test.dmg\" hash=\"vaQXjdS1P6VP31rkqe8YuzbNzvk=\" needsadmin=\"true\" size=\"5910016\" status=\"ok\" Prompt=\"true\" RequireReboot=\"true\" MoreInfo=\"http://desktop.google.com/mac/${hl}/foobage.html\" LocalizationBundle=\"/Hassel/Hoff\" DisplayVersion=\"3.1.4\" Version=\"3.1.4 (lolcat)\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"</gupdate>";

static char *kMegaResponseStringHeader =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"   <daystart elapsed_seconds=\"300\" />";

static char *kMegaResponseStringAppFormat =
"    <app appid=\"%@\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test2.dmg\" hash=\"hcqiyPD01sWXVdYHNpWe4H2OBak=\" needsadmin=\"false\" size=\"1868800\" status=\"ok\"></updatecheck>"
"        <rlz status=\"ok\"></rlz>"
"        <ping status=\"ok\"></ping>"
"    </app>";

static char *kMegaResponseStringFooter =
"</gupdate>";

- (void)testMultiResponse {
  // 2 apps
  NSArray *updateInfos = [self updateInfoForStr:kMultiResponseString];
  STAssertEquals([updateInfos count], 2U, nil);
  KSUpdateInfo *info = nil;
  NSEnumerator *infoEnumerator = [updateInfos objectEnumerator];
  while ((info = [infoEnumerator nextObject])) {
    if ([[info productID] isEqualToString:@"{26EA52A6-C1F2-11DB-B91C-B0B155D89593}"]) {
      // 1 - The first app listed in kMultiResponseString
      STAssertEqualObjects([info codebaseURL], [NSURL URLWithString:@"http://tools.google.com/omaha_download/test2.dmg"], nil);
      STAssertEqualObjects([info codeSize], [NSNumber numberWithInt:1868800], nil);
      STAssertEqualObjects([info codeHash], @"hcqiyPD01sWXVdYHNpWe4H2OBak=", nil);
      STAssertFalse([[info promptUser] boolValue], nil);
      STAssertFalse([[info requireReboot] boolValue], nil);
      STAssertEqualObjects([info moreInfoURLString], @"http://google.com", nil);
    } else if ([[info productID] isEqualToString:@"{8A69D345-D564-463C-AFF1-A69D9E530F96}"]) {
      // 2 - The second app listed in kMultiResponseString
      STAssertEqualObjects([info codebaseURL], [NSURL URLWithString:@"http://tools.google.com/omaha_download/test.dmg"], nil);
      STAssertEqualObjects([info codeSize], [NSNumber numberWithInt:5910016], nil);
      STAssertEqualObjects([info codeHash], @"vaQXjdS1P6VP31rkqe8YuzbNzvk=", nil);
      STAssertTrue([[info promptUser] boolValue], nil);
      STAssertTrue([[info requireReboot] boolValue], nil);
      STAssertEqualObjects([info moreInfoURLString],
                           @"http://desktop.google.com/mac/${hl}/foobage.html",
                           nil);
      STAssertEqualObjects([info localizationBundle], @"/Hassel/Hoff", nil);
      STAssertEqualObjects([info displayVersion], @"3.1.4", nil);
      STAssertEqualObjects([info version], @"3.1.4 (lolcat)", nil);
    }
  }

  // 101 apps
  unsigned int count = 101;
  NSMutableString *mega = [NSMutableString stringWithCapacity:4096];
  [mega appendString:[NSString stringWithCString:kMegaResponseStringHeader]];
  for (int x = 0; x < count; x++) {
    NSString *megaf = [NSString stringWithCString:kMegaResponseStringAppFormat];
    [mega appendString:[NSString stringWithFormat:megaf,
                                 [NSString stringWithFormat:@"{guid-%d}", x]]];
  }
  [mega appendString:[NSString stringWithCString:kMegaResponseStringFooter]];
  updateInfos = [self updateInfoForStr:[mega UTF8String]];
  STAssertEquals([updateInfos count], count, nil);
}

- (NSDictionary *)paramsDict {
  // Yes, this is active.
  NSDictionary *product0Params = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:YES], kUpdateEngineProductStatsActive, nil];
  // No, this is not active.
  NSDictionary *product1Params = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:NO], kUpdateEngineProductStatsActive, nil];
  // Active not explicitly set.
  NSDictionary *product2Params = [NSDictionary dictionary];

  NSDictionary *productStats = [NSDictionary dictionaryWithObjectsAndKeys:
     product0Params, @"{guid-0}",
     product1Params, @"{guid-1}",
     product2Params, @"{guid-2}",
     nil];

  NSString *sp = @"10.982.903404";
  NSString *tag = @"aJEyA_is_our_tesTER";
  NSArray *objects = [NSArray arrayWithObjects:sp, tag, @"1",
                              productStats, nil];
  NSArray *keys = [NSArray arrayWithObjects:
                           kUpdateEngineOSVersion,
                           kUpdateEngineUpdateCheckTag,
                           kUpdateEngineIsMachine,
                           kUpdateEngineProductStats,
                           nil];

  NSDictionary *params = [NSDictionary dictionaryWithObjects:objects
                                                     forKeys:keys];
  return params;
}

- (void)testParams {

  NSDictionary *params = [self paramsDict];
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_ params:params];
  NSMutableArray *oneTicket = [NSMutableArray arrayWithCapacity:1];
  [oneTicket addObject:[httpTickets_ objectAtIndex:0]];

  NSArray *requests = [server requestsForTickets:oneTicket];
  STAssertNotNil(requests, nil);
  STAssertTrue([requests count] == 1, nil);
  STAssertTrue([[requests objectAtIndex:0] isKindOfClass:[NSURLRequest class]],
               nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  NSString *sp = [params objectForKey:kUpdateEngineOSVersion];
  NSString *tag = [params objectForKey:kUpdateEngineUpdateCheckTag];

  [self findInDoc:doc path:@".//o:gupdate/o:app" count:1];
  NSXMLNode *node;
  node = [self findInDoc:doc path:@".//o:gupdate/o:os/@version" count:1];
  STAssertTrue([[node stringValue] isEqual:@"MacOSX"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/o:os/@platform" count:1];
  STAssertTrue([[node stringValue] isEqual:@"mac"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/o:os/@sp" count:1];
  STAssertTrue([[node stringValue] isEqual:sp], nil);

  node = [self findInDoc:doc path:@".//o:gupdate/@version" count:1];
  STAssertTrue([[node stringValue] hasPrefix:@"UpdateEngine-"], nil);
  node = [self findInDoc:doc path:@".//o:gupdate/@ismachine" count:1];
  STAssertTrue([[node stringValue] isEqual:@"1"], nil);

  node = [self findInDoc:doc path:@".//o:gupdate/@tag" count:1];
  STAssertTrue([[node stringValue] isEqual:tag], nil);

  // Make sure changing the identity affects the request.
  NSMutableDictionary *mutableParams = [[params mutableCopy] autorelease];
  [mutableParams setObject:@"Monkeys" forKey:kUpdateEngineIdentity];
  server = [KSOmahaServer serverWithURL:httpURL_ params:mutableParams];
  requests = [server requestsForTickets:oneTicket];
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  node = [self findInDoc:doc path:@".//o:gupdate/@version" count:1];
  STAssertTrue([[node stringValue] hasPrefix:@"Monkeys-"], nil);
}

- (void)testStats {
  NSURL *url = [NSURL URLWithString:@"https://www.google.com"];
  KSOmahaServer *omaha = [KSOmahaServer serverWithURL:url];
  STAssertNotNil(omaha, nil);

  NSURLRequest *request = nil;
  request = [omaha requestForStats:nil];
  STAssertNil(request, nil);

  KSStatsCollection *stats = [KSStatsCollection statsCollectionWithPath:@"/dev/null"
                                                        autoSynchronize:NO];
  STAssertNotNil(stats, nil);

  request = [omaha requestForStats:stats];
  STAssertNil(request, nil);

  // OK, now set some real stats, and make sure they show up correctly in the
  // XML request

  [stats incrementStat:@"foo"];
  [stats incrementStat:@"bar"];
  [stats decrementStat:@"baz"];

  [stats incrementStat:KSMakeProductStatKey(@"com.google.test1", kStatInstallRC)];
  [stats incrementStat:KSMakeProductStatKey(@"com.google.test1", kStatInstallRC)];

  [stats incrementStat:KSMakeProductStatKey(@"com.google.test2", kStatInstallRC)];
  [stats incrementStat:KSMakeProductStatKey(@"com.google.test2", kStatActiveProduct)];

  [stats incrementStat:KSMakeProductStatKey(@"com.google.test3", kStatActiveProduct)];

  request = [omaha requestForStats:stats];
  STAssertNotNil(request, nil);

  NSData *data = [request HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  NSXMLNode *node = nil;

  // Check the "kstat" element
  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat" count:1];
  STAssertNotNil(node, nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat/@foo" count:1];
  STAssertEqualObjects([node stringValue], @"1", nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat/@bar" count:1];
  STAssertEqualObjects([node stringValue], @"1", nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:kstat/@baz" count:1];
  STAssertEqualObjects([node stringValue], @"-1", nil);


  // Check the per-app stats
  [self findInDoc:doc path:@"//o:gupdate/o:app/@appid" count:3];

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test1']/o:event" count:1];
  STAssertNotNil(node, nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test1']/o:event/@errorcode" count:1];
  STAssertNotNil(node, nil);
  STAssertEqualObjects([node stringValue], @"2", nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test2']/o:event" count:1];
  STAssertNotNil(node, nil);

  node = [self findInDoc:doc path:@"//o:gupdate/o:app[@appid='com.google.test2']/o:event/@errorcode" count:1];
  STAssertNotNil(node, nil);
  STAssertEqualObjects([node stringValue], @"1", nil);
}

// Get a subdictionary out of a dictionary, creating it if necessary.
- (NSMutableDictionary *)dictInDict:(NSMutableDictionary *)dict
                             forKey:(NSString *)key {
  NSMutableDictionary *subDict = [dict objectForKey:key];
  if (subDict == nil) {
    subDict = [NSMutableDictionary dictionary];
    [dict setObject:subDict forKey:key];
  }
  return subDict;
}

// Add an "ActiveInfo" dictionary for the given productID and the given
// dates.  Final results are suitable for framing.  And for passing as an
// engine parameter.
- (void)addRollCallPing:(NSDate *)rcp
         lastActivePing:(NSDate *)lap
             lastActive:(NSDate *)la
           forProductID:(NSString *)productID
               intoDict:(NSMutableDictionary *)dict {
  NSMutableDictionary *productInfo =
    [self dictInDict:dict forKey:kUpdateEngineProductActiveInfoKey];
  NSMutableDictionary *productDict = [self dictInDict:productInfo
                                               forKey:productID];
  if (rcp) [productDict setObject:rcp forKey:kUpdateEngineLastRollCallPingDate];
  if (lap) [productDict setObject:lap forKey:kUpdateEngineLastActivePingDate];
  if (la) [productDict setObject:rcp forKey:kUpdateEngineLastActiveDate];
}

// Response string that includes four app responses, which correspond to
// guid-[0-3] tickets in -testActives.
static char *kActivesResponseString =
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<gupdate xmlns=\"http://www.google.com/update2/response\" protocol=\"2.0\">"
"   <daystart elapsed_seconds=\"300\" />"
"    <app appid=\"{guid-0}\" status=\"ok\">"
"        <updatecheck codebase=\"http://tools.google.com/omaha_download/test.dmg\" hash=\"vaQXjdS1P6VP31rkqe8YuzbNzvk=\" needsadmin=\"true\" size=\"5910016\" status=\"ok\"></updatecheck>"
"        <ping status=\"ok\"></ping>"
"    </app>"
"    <app appid=\"{guid-1}\" status=\"ok\">"
"        <updatecheck status=\"noupdate\" />"
"        <ping status=\"ok\"></ping>"
"    </app>"
"    <app appid=\"{guid-2}\" status=\"ok\">"
"        <updatecheck status=\"noupdate\" />"
"        <ping status=\"ok\"></ping>"
"    </app>"
"    <app appid=\"{guid-3}\" status=\"ok\">"
"        <updatecheck status=\"noupdate\" />"
"    </app>"
"</gupdate>";

- (void)testActives {
  serverDataDict_ = [NSMutableDictionary dictionary];
  KSTicketStore *store = [[[KSMemoryTicketStore alloc] init] autorelease];
  KSUpdateEngine *engine = [KSUpdateEngine engineWithTicketStore:store
                                                        delegate:self];
  STAssertNotNil(engine, nil);
  NSMutableDictionary *params = [NSMutableDictionary dictionary];
  // Set up the params dictionary.  First the server params.

  // And then a couple of products.
  [self addRollCallPing:nil  // expect 'r="-1"' (first report)
         lastActivePing:nil  // no 'a' since there's no active
             lastActive:nil
           forProductID:@"{guid-0}"
               intoDict:params];
  [self addRollCallPing:[self hoursAgo:5]  // expect no r since < 24 hours
         lastActivePing:[self hoursAgo:49]  // expect 'a="2"'
             lastActive:[self hoursAgo:12]
           forProductID:@"{guid-1}"
               intoDict:params];
  [self addRollCallPing:[self hoursAgo:50]  // expect 'r="2"'.
         lastActivePing:[self hoursAgo:73]  // expect 'a="3"
             lastActive:[self hoursAgo:1]
           forProductID:@"{guid-2}"
               intoDict:params];
  [self addRollCallPing:[self hoursAgo:1]  // expect no r since < 24 hours
         lastActivePing:[self hoursAgo:1]  // expect no a since < 24 hours
             lastActive:nil                // and so should get no o:ping node.
           forProductID:@"{guid-3}"
               intoDict:params];

  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:params
                                                engine:engine];
  STAssertNotNil([server engine], nil);
  KSClientActives *ac = [server valueForKey:@"actives_"];
  STAssertNotNil(ac, nil);

  // Make sure the expected "r=" and "a=" values come from the clientactives.
  STAssertEquals([ac rollCallDaysForProductID:@"{guid-0}"],
                 kKSClientActivesFirstReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"{guid-0}"],
                 kKSClientActivesDontReport, nil);

  STAssertEquals([ac rollCallDaysForProductID:@"{guid-1}"],
                 kKSClientActivesDontReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"{guid-1}"], 2, nil);

  STAssertEquals([ac rollCallDaysForProductID:@"{guid-2}"], 2, nil);
  STAssertEquals([ac activeDaysForProductID:@"{guid-2}"], 3, nil);

  STAssertEquals([ac rollCallDaysForProductID:@"{guid-3}"],
                 kKSClientActivesDontReport, nil);
  STAssertEquals([ac activeDaysForProductID:@"{guid-3}"],
                 kKSClientActivesDontReport, nil);

  // Generate the request.
  NSMutableArray *tickets = [NSMutableArray array];
  for (int i = 0; i < 4; i++) {
    [tickets addObject:[self ticketWithURL:httpURL_ count:i]];
  }
  NSArray *requests = [server requestsForTickets:tickets];
  STAssertEquals([requests count], (unsigned)1, nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];

  // Make sure we have the proper o:pings in there.
  NSXMLNode *node = nil;
  // guid-0 has r=-1 and no a
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-0}']/o:ping/@a"
                   count:0];
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-0}']/o:ping/@r"
                   count:1];
  STAssertEqualObjects([node stringValue], @"-1", nil);
  STAssertTrue([ac didSendRollCallForProductID:@"{guid-0}"], nil);
  STAssertFalse([ac didSendActiveForProductID:@"{guid-0}"], nil);
  // guid-1 has no r and a=2
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-1}']/o:ping/@a"
                   count:1];
  STAssertEqualObjects([node stringValue], @"2", nil);
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-1}']/o:ping/@r"
                   count:0];
  STAssertFalse([ac didSendRollCallForProductID:@"{guid-1}"], nil);
  STAssertTrue([ac didSendActiveForProductID:@"{guid-1}"], nil);
  // guid-2 has r=2, a=3
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-2}']/o:ping/@a"
                   count:1];
  STAssertEqualObjects([node stringValue], @"3", nil);
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-2}']/o:ping/@r"
                   count:1];
  STAssertEqualObjects([node stringValue], @"2", nil);
  STAssertTrue([ac didSendRollCallForProductID:@"{guid-2}"], nil);
  STAssertTrue([ac didSendActiveForProductID:@"{guid-2}"], nil);
  // guid-3 has neither, so should have no o:ping block
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-3}']/o:ping/@a"
                   count:0];
  node = [self findInDoc:doc
                    path:@"//o:gupdate/o:app[@appid='{guid-3}']/o:ping/@r"
                   count:0];
  STAssertFalse([ac didSendRollCallForProductID:@"{guid-3}"], nil);
  STAssertFalse([ac didSendActiveForProductID:@"{guid-3}"], nil);

  // To continue this never-ending test, feed KSOmahaServer a response and
  // make sure the delegate method is called appropriately
  data = [NSData dataWithBytes:kActivesResponseString
                        length:strlen(kActivesResponseString)];
  STAssertNotNil(data, nil);
  NSArray *results = [server updateInfosForResponse:nil
                                               data:data
                                      outOfBandData:NULL];
  STAssertEquals([results count], (unsigned)1, nil);  // Just one update.

  // Make sure we got three delegate notifications.
  STAssertEquals([serverDataDict_ count], (unsigned)3, nil);
  NSMutableDictionary *productDict;

  productDict = [serverDataDict_ objectForKey:@"{guid-0}"];
  STAssertNotNil(productDict, nil);
  // If the recorded times are within 30 seconds of now, consider it "now"
  // the "300" comes from the daystart/elapsed_seconds value in the response,
  // which is used to bias the ping date, and because this is sparta.
  STAssertTrue([[productDict objectForKey:kUpdateEngineLastRollCallPingDate]
                 timeIntervalSinceNow] > -330, nil);
  STAssertNil([productDict objectForKey:kUpdateEngineLastActivePingDate], nil);

  productDict = [serverDataDict_ objectForKey:@"{guid-1}"];
  STAssertNotNil(productDict, nil);
  STAssertNil([productDict objectForKey:kUpdateEngineLastRollCallPingDate],
              nil);
  STAssertTrue([[productDict objectForKey:kUpdateEngineLastActivePingDate]
                 timeIntervalSinceNow] > -330, nil);

  productDict = [serverDataDict_ objectForKey:@"{guid-2}"];
  STAssertNotNil(productDict, nil);
  STAssertTrue([[productDict objectForKey:kUpdateEngineLastRollCallPingDate]
                 timeIntervalSinceNow] > -330, nil);
  STAssertTrue([[productDict objectForKey:kUpdateEngineLastActivePingDate]
                 timeIntervalSinceNow] > -330, nil);

  // guid-3 did not have an o:ping block, so there shold be no delegate
  // notification.
  productDict = [serverDataDict_ objectForKey:@"{guid-3}"];
  STAssertNil(productDict, nil);
}

// Fill in stuff from delegate method that should be called from -testActives.
- (void)engine:(KSUpdateEngine *)engine
    serverData:(id)stuff
  forProductID:(NSString *)productID
       withKey:(NSString *)key {
  NSMutableDictionary *productDict = [self dictInDict:serverDataDict_
                                               forKey:productID];
  [productDict setObject:stuff forKey:key];
}


- (void)testInstallAge {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  // Make a date.  The little bit of extra is to ensure we go beyond three days.
  NSTimeInterval threeDaysAgo = 3 * 24 * 60 * 60 + 37;
  NSDate *creationDate = [NSDate dateWithTimeIntervalSinceNow:-threeDaysAgo];
  STAssertNotNil(creationDate, nil);

  KSTicket *t = [self ticketWithURL:httpURL_
                              count:0
                       creationDate:creationDate];
  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *installage =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@installage" count:1];
  // Convert XML element 'installage="X"' to @"X".
  NSString *value = [installage valueForKey:@"stringValue"];
  STAssertEqualObjects(@"3", value, nil);

  // Check a date from the future!
  NSTimeInterval oneWeekFromNow = 7 * 24 * 60 * 60 + 42;

  creationDate = [NSDate dateWithTimeIntervalSinceNow:oneWeekFromNow];
  STAssertNotNil(creationDate, nil);

  t = [self ticketWithURL:httpURL_
                    count:0
             creationDate:creationDate];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  installage =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@installage" count:0];
  // Should be nothing there.
  STAssertEqualObjects(installage, [NSArray array], nil);
}

- (void)testTag {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  KSTicket *t = [self ticketWithURL:httpURL_
                              count:0
                                tag:@"oonga woonga"];
  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *tagNode =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@tag" count:1];

  // Convert XML element 'tag="X"' to @"X".
  NSString *value = [tagNode valueForKey:@"stringValue"];
  STAssertEqualObjects(@"oonga woonga", value, nil);

  // No tag should result in no "tag".
  t = [self ticketWithURL:httpURL_ count:0];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  tagNode = [self findInDoc:doc path:@".//o:gupdate/o:app/@tag" count:0];
}

- (void)testBrand {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  KSTicket *t =
    [self ticketWithURL:httpURL_
                  count:0
              brandPath:@"/Applications/TextEdit.app/Contents/Info.plist"
               brandKey:@"CFBundleDisplayName"];

  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *brandNode =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@brand" count:1];

  // Convert XML element 'brand="X"' to @"X".
  NSString *value = [brandNode valueForKey:@"stringValue"];
  STAssertEqualObjects(@"TextEdit", value, nil);

  // No brand should result in the default "GGLG" brand.
  t = [self ticketWithURL:httpURL_ count:0];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  brandNode = [self findInDoc:doc path:@".//o:gupdate/o:app/@brand" count:1];
  value = [brandNode valueForKey:@"stringValue"];
  STAssertEqualObjects(DEFAULT_BRAND_CODE, value, nil);
}

- (void)testVersion {
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:nil];
  STAssertNotNil(server, nil);

  // Use the application name instead of its version, since the TextEdit's
  // version probably is not as stable the name.
  KSTicket *t =
    [self ticketWithURL:httpURL_
                  count:0
            versionPath:@"/Applications/TextEdit.app/Contents/Info.plist"
             versionKey:@"CFBundleDisplayName"
                version:nil];

  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSString *versionNode =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@version" count:1];

  // Convert XML element 'version="X"' to @"X".
  NSString *value = [versionNode valueForKey:@"stringValue"];
  STAssertEqualObjects(@"TextEdit", value, nil);

  // No version tag/path should result in the ticket's version being used.
  t = [self ticketWithURL:httpURL_ count:0];
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  STAssertEquals((unsigned)1, [requests count], nil);
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  versionNode =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@version" count:1];
  value = [versionNode valueForKey:@"stringValue"];
  STAssertEqualObjects(@"1.0", value, nil);
}

- (void)testIsAllowedURL {
  NSURL *url = [NSURL URLWithString:@"https://placeholder.com"];
  KSOmahaServer *server = [KSOmahaServer serverWithURL:url params:nil];

  STAssertFalse([server isAllowedURL:nil], nil);

#ifdef DEBUG
  // In DEBUG mode, everything is allowed.  Go nuts.
  url = [NSURL URLWithString:@"file:///bin/ls"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"http://google.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://google.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"fish://glub/glub"];
  STAssertTrue([server isAllowedURL:url], nil);
#else
  // In release mode, all non-https urls are summarily rejected.
  url = [NSURL URLWithString:@"file:///bin/ls"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"http://google.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"pheasant://grouse/grouse"];
  STAssertFalse([server isAllowedURL:url], nil);

  // If no allowed subdomains are supplied, allow any https urls.
  url = [NSURL URLWithString:@"https://snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);

  // Supply a set of allowed subdomains, and make sure those are, well,
  // allowed.
  NSArray *allowedSubdomains = [NSArray arrayWithObjects:
                                        @".update.snorklegronk.com",
                                        @".www.snorklegronk.com",
                                        @".intranet.grouse.grouse", nil];
  NSDictionary *params =
    [NSDictionary dictionaryWithObjectsAndKeys:allowedSubdomains,
                  kUpdateEngineAllowedSubdomains, nil];
  url = [NSURL URLWithString:@"https://pheasant.intranet.grouse.grouse"];
  server = [KSOmahaServer serverWithURL:url params:params];

  // Make sure allowed domains are allowed.
  url = [NSURL URLWithString:@"https://update.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://splunge.update.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://intranet.grouse.grouse"];
  STAssertTrue([server isAllowedURL:url], nil);

  // And double-check other domains
  url = [NSURL URLWithString:@"https://backup.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  // Don't allow cloaking.
  url = [NSURL URLWithString:@"https://www.snorklegronk.com.badguy.com"];
  STAssertFalse([server isAllowedURL:url], nil);

  // And sanity check that non-https are still rejected.
  url = [NSURL URLWithString:@"file:///update.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"http://www.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"pheasant://grouse.grouse.grouse"];
  STAssertFalse([server isAllowedURL:url], nil);

  // Make sure overlapping domains don't cause unexpected behavior
  allowedSubdomains = [NSArray arrayWithObjects:
                               @".www.snorklegronk.com",
                               @".www.snorklegronk.com", nil];
  params = [NSDictionary dictionaryWithObjectsAndKeys:allowedSubdomains,
                         kUpdateEngineAllowedSubdomains, nil];
  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  server = [KSOmahaServer serverWithURL:url params:params];

  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://monkeys.www.snorklegronk.com"];
  STAssertTrue([server isAllowedURL:url], nil);
  url = [NSURL URLWithString:@"https://backup.snorklegronk.com"];
  STAssertFalse([server isAllowedURL:url], nil);
#endif
}

- (void)testOutOfBandData {
  NSURL *url = [NSURL URLWithString:@"https://placeholder.com"];
  KSOmahaServer *server = [KSOmahaServer serverWithURL:url params:nil];
  STAssertNotNil(server, nil);

  // No out of band data.
  NSData *data = [NSData dataWithBytes:kSingleResponseString
                                length:strlen(kSingleResponseString)];
  NSDictionary *oob;
  NSArray *infos = [server updateInfosForResponse:nil
                                             data:data
                                    outOfBandData:&oob];
  STAssertEquals([infos count], (unsigned)1, nil);
  STAssertNil(oob, nil);

  // Out-of-band data.
  data = [NSData dataWithBytes:kSingleResponseStringWithDaystart
                        length:strlen(kSingleResponseStringWithDaystart)];
  infos = [server updateInfosForResponse:nil
                                    data:data
                           outOfBandData:&oob];
  STAssertEquals([infos count], (unsigned)1, nil);
  STAssertNotNil(oob, nil);
  STAssertEqualObjects([oob objectForKey:KSOmahaServerSecondsSinceMidnightKey],
                       [NSNumber numberWithInt:300], nil);

  // Out-of-band data, but no products needing update.  Should still
  // result in oob data being returned.
  data = [NSData dataWithBytes:kNoResponseStringWithDaystart
                        length:strlen(kNoResponseStringWithDaystart)];
  infos = [server updateInfosForResponse:nil
                                    data:data
                           outOfBandData:&oob];
  STAssertEquals([infos count], (unsigned)0, nil);
  STAssertNotNil(oob, nil);
  STAssertEqualObjects([oob objectForKey:KSOmahaServerSecondsSinceMidnightKey],
                       [NSNumber numberWithInt:19283], nil);
}

- (void)testInstallSource {
  NSDictionary *params =
    [NSDictionary dictionaryWithObjectsAndKeys:
                  [NSNumber numberWithBool:YES], kUpdateEngineUserInitiated,
                  nil];
  KSOmahaServer *server = [KSOmahaServer serverWithURL:httpURL_
                                                params:params];
  STAssertNotNil(server, nil);
  KSTicket *t = [self ticketWithURL:httpURL_
                              count:0];
  NSArray *requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  NSData *data = [[requests objectAtIndex:0] HTTPBody];
  NSXMLDocument *doc = [self documentFromRequest:data];
  NSXMLNode *installsource =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@installsource" count:1];
  STAssertEqualObjects([installsource stringValue], @"ondemandupdate", nil);

  // Lack of a user-initiated parameter should result in no installsource.
  server = [KSOmahaServer serverWithURL:httpURL_
                                 params:nil];
  STAssertNotNil(server, nil);
  requests = [server requestsForTickets:[NSArray arrayWithObject:t]];
  data = [[requests objectAtIndex:0] HTTPBody];
  doc = [self documentFromRequest:data];
  installsource =
    [self findInDoc:doc path:@".//o:gupdate/o:app/@installsource" count:0];
}

@end

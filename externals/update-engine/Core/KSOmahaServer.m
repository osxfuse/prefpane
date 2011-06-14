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

#import "KSOmahaServer.h"
#include <sys/param.h>
#include <sys/mount.h>
#include <unistd.h>
#import "KSClientActives.h"
#import "KSFrameworkStats.h"
#import "KSStatsCollection.h"
#import "KSTicket.h"
#import "KSUpdateEngine.h"
#import "KSUpdateEngineParameters.h"
#import "KSUpdateInfo.h"

// The brand code to report in the update request if there is no other
// brand code supplied via the ticket.
#define DEFAULT_BRAND_CODE @"GGLG"

@interface KSOmahaServer (Private)

// Walk the product actives dictionary provided in the UpdateEngine parameters
// and fill populate |actives_| for later use.
- (void)setupActives;

// Return an NSDictionary with default settings for all params. This is a class
// method because it needs to be called before a class instance is initialized
// (i.e., before [super init...] is called).
+ (NSMutableDictionary *)defaultParams;

// Builds the XML |document_| and |root_| for the Omaha request based on the
// stats contained in |stats|.
- (void)buildDocumentForStats:(KSStatsCollection *)stats;

// begin construciton of the XML document used for a request
- (void)createRootAndDocument;

// Returns an NSXMLElement for the specified application ID. If an element with
// appID is already attached to |root_|, that one is returned. Otherwise, a new
// one is created and returned.
- (NSXMLElement *)elementForApp:(NSString *)appID;

// add an incremental amount more of XML based on one KSTicket
- (NSXMLElement *)elementFromTicket:(KSTicket *)t;

// convenience wrapper for element+attribute creation
- (NSXMLElement *)addElement:(NSString *)name withAttribute:(NSString *)attr
                 stringValue:(NSString *)value toParent:(NSXMLElement *)parent;

// See if the given productID needs to have an <o:ping> element added to
// the update request.  |actives_| is used to determine whether this
// element is needed, and what the element's attributes should be.
- (void)addPingElementForProductID:(NSString *)productID
                          toParent:(NSXMLElement *)parent;

// Return the complete NSData object for an XML document (e.g. including header)
- (NSData *)dataFromDocument;

// Returns a dictionary containing NSString key/value pairs for all of the XML
// attributes of |node|.
- (NSMutableDictionary *)dictionaryWithXMLAttributesForNode:(NSXMLNode *)node;

// Given a dictionary of key/value attributes (as NSStrings), returns the
// corresponding KSUpdateInfo object. If required keys are missing, nil will
// be returned.
- (KSUpdateInfo *)updateInfoWithAttributes:(NSDictionary *)attributes;

// Returns YES if the specified |url| is safe to fetch; NO otherwise. See the
// implementation for more details about what's safe and what's not.
- (BOOL)isAllowedURL:(NSURL *)url;

@end


@implementation KSOmahaServer

+ (id)serverWithURL:(NSURL *)url {
  return [self serverWithURL:url params:nil];
}

+ (id)serverWithURL:(NSURL *)url params:(NSDictionary *)params {
  return [[[self alloc] initWithURL:url params:params] autorelease];
}

+ (id)serverWithURL:(NSURL *)url params:(NSDictionary *)params
             engine:(KSUpdateEngine *)engine {
  return [[[self alloc] initWithURL:url params:params engine:engine]
           autorelease];
}

- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params
           engine:(KSUpdateEngine *)engine {
  // First thing, we need to create our params dictionary, which has some
  // default values that can be overriden by the caller-specified |params|.
  // The -addEntriesFromDictionary call will replace (override) existing values,
  // which is what we want.
  NSMutableDictionary *defaultParams = [[self class] defaultParams];
  if (params)
    [defaultParams addEntriesFromDictionary:params];

  if ((self = [super initWithURL:url params:defaultParams engine:engine])) {
    if (![self isAllowedURL:url]) {
      // These lines can never be hit in debug unit test builds because debug
      // builds allow all URLs, so this block could never be hit.
      GTMLoggerError(@"Denying connection to %@", url);  // COV_NF_LINE
      [self release];                                    // COV_NF_LINE
      return nil;                                        // COV_NF_LINE
    }
    [self setupActives];
  }

  return self;
}

- (void)dealloc {
  [document_ release];
  [actives_ release];
  [super dealloc];
}

- (NSArray *)requestsForTickets:(NSArray *)tickets {
  if ([tickets count] == 0)
    return nil;
  // make sure they're all for me
  NSEnumerator *tenum = [tickets objectEnumerator];
  KSTicket *t = nil;
  while ((t = [tenum nextObject])) {
    if (![[self url] isEqual:[t serverURL]]) {
      GTMLoggerError(@"Tickets found with bad URL");
      return nil;
    }
  }
  [self createRootAndDocument];

  tenum = [tickets objectEnumerator];
  while ((t = [tenum nextObject])) {
    [root_ addChild:[self elementFromTicket:t]];
  }
  NSData *data = [self dataFromDocument];
  NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:[self url]];
  [request setHTTPMethod:@"POST"];
  [request setHTTPBody:data];

  GTMLoggerInfo(@"request: %@", [self prettyPrintResponse:nil data:data]);

  // return an array of the one item
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
  [array addObject:request];
  return array;
}

// response can be nil; we never look at it.
- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob {
  if (data == nil)
    return nil;

  GTMLoggerInfo(@"response: %@", [self prettyPrintResponse:nil data:data]);

  // No out-of-band data until we find some.
  if (oob) *oob = nil;

  NSError *error = nil;
  NSXMLDocument *doc = [[[NSXMLDocument alloc]
                         initWithData:data
                              options:0
                                error:&error]
                          autorelease];
  if (error != nil) {
    GTMLoggerError(@"XML error %@ when parsing response", error);
    return nil;
  }

  NSArray *apps = [doc nodesForXPath:@".//gupdate/app" error:&error];
  if (error != nil) {
    GTMLoggerError(@"XML error %@ when looking for .//gupdate/app",  // COV_NF_LINE
                   error);
    return nil;  // COV_NF_LINE
  }

  // Look for <daystart elapsed_seconds="300" />, an optional return value.
  // Return an out-of-band dictionary if it exists (and the caller wants it).
  NSArray *daystarts = [doc nodesForXPath:@".//gupdate/daystart" error:&error];
    // Pick off one and get its attribute.
  if ([daystarts count] > 0) {
    NSXMLNode *daystartNode = [daystarts objectAtIndex:0];
    NSMutableDictionary *attributes =
      [self dictionaryWithXMLAttributesForNode:daystartNode];
    NSString *elapsedSecondsString =
      [attributes objectForKey:@"elapsed_seconds"];
    secondsSinceMidnight_ = [elapsedSecondsString intValue];

    if (oob) {
      NSDictionary *oobData =
        [NSDictionary
          dictionaryWithObject:[NSNumber numberWithInt:secondsSinceMidnight_]
                        forKey:KSOmahaServerSecondsSinceMidnightKey];
      *oob = oobData;
    }
  }

  // The array of update infos that we will return
  NSMutableArray *updateInfos = [NSMutableArray array];
  NSEnumerator *aenum = [apps objectEnumerator];
  NSXMLElement *element = nil;

  // Iterate through each <app ...> ... </app> element
  while ((element = [aenum nextObject])) {

    // First, make sure the status of the <app> is "ok"
    NSArray *statusNodes = [element nodesForXPath:@"./@status" error:&error];
    if (error != nil || [statusNodes count] == 0) {
      GTMLoggerError(@"No statuses for %@, error=%@", element, error);
      continue;
    }
    NSString *status = [[statusNodes objectAtIndex:0] stringValue];
    if (![status isEqualToString:@"ok"]) {
      GTMLoggerError(@"Bad status for %@", element);
      continue;
    }

    // Now, collect all the attributes of "./updatecheck"
    // (<app><updatecheck ...></updatecheck></app>) into a mutable dictionary.
    // We'll make sure we got all the required attributes later.
    NSArray *updateCheckNodes = [element nodesForXPath:@"./updatecheck"
                                                 error:&error];
    if (error != nil || [updateCheckNodes count] == 0) {
      GTMLoggerError(@"Failed to get updatecheck from %@, error=%@",
                     element, error);
      continue;
    }
    NSXMLNode *updatecheckNode = [updateCheckNodes objectAtIndex:0];

    NSMutableDictionary *attributes =
      [self dictionaryWithXMLAttributesForNode:updatecheckNode];
    GTMLoggerInfo(@"Attributes from XMLNode %@ = %@",
                  updatecheckNode, [attributes description]);

    // Pick up the product ID from the appid attribute
    // (<app appid="..."></app>)
    NSArray *appIDNodes = [element nodesForXPath:@"./@appid" error:&error];
    if (error != nil || [appIDNodes count] == 0) {
      GTMLoggerError(@"Failed to get appid from %@, error=%@",
                     element, error);
      continue;
    }
    NSXMLNode *appID = [appIDNodes objectAtIndex:0];
    NSString *productID = [appID stringValue];

    // Notify the delegate about the ping successes before possibly
    // bailing out for a "noupdate" status.
    id delegate = [[self engine] delegate];
    if (delegate) {
      NSArray *pingNodes = [element nodesForXPath:@"./ping/@status"
                                            error:&error];
      if ([pingNodes count] > 0) {
        NSXMLNode *pingNode = [pingNodes objectAtIndex:0];
        if ([[pingNode stringValue] isEqualToString:@"ok"]) {
          NSDate *biasedNow =
            [NSDate dateWithTimeIntervalSinceNow:-secondsSinceMidnight_];
          if ([delegate respondsToSelector:
                          @selector(engine:serverData:forProductID:withKey:)]) {
            if ([actives_ didSendRollCallForProductID:productID]) {
              [delegate engine:[self engine]
                    serverData:biasedNow
                  forProductID:productID
                       withKey:kUpdateEngineLastRollCallPingDate];
            }
            if ([actives_ didSendActiveForProductID:productID]) {
              [delegate engine:[self engine]
                    serverData:biasedNow
                  forProductID:productID
                       withKey:kUpdateEngineLastActivePingDate];
            }
          }
        }
      }
    }

    // Make sure the "status" attribute of the "updatecheck" node is "ok"
    if (![[attributes objectForKey:@"status"] isEqualToString:@"ok"]) {
      continue;
    }

    // Stuff the appid (product ID) into our attributes dictionary
    [attributes setObject:productID forKey:kServerProductID];

    // Build a KSUpdateInfo from the XML attributes and add that to our
    // array of update infos to return.
    KSUpdateInfo *updateInfo = [self updateInfoWithAttributes:attributes];
    if (updateInfo) {
      [updateInfos addObject:updateInfo];
    } else {
      GTMLoggerError(@"can't create KSUpdateInfo from element %@", element);
    }
  }

  return updateInfos;
}

- (NSString *)prettyPrintResponse:(NSURLResponse *)response
                             data:(NSData *)data {
  NSError *error = nil;
  NSXMLDocument *doc = [[[NSXMLDocument alloc]
                         initWithData:data
                         options:0
                         error:&error]
                        autorelease];
  if (error != nil) {
    GTMLoggerError(@"XML error %@ when printing response", error);
    return nil;
  }

  NSData *d2 = [doc XMLDataWithOptions:NSXMLNodePrettyPrint];
  NSString *str = [[[NSString alloc] initWithData:d2
                                         encoding:NSUTF8StringEncoding]
                   autorelease];
  return str;
}

- (NSURLRequest *)requestForStats:(KSStatsCollection *)stats {
  if ([stats count] == 0)
    return nil;

  [self buildDocumentForStats:stats];
  NSData *data = [self dataFromDocument];

  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self url]];
  [req setHTTPMethod:@"POST"];
  [req setHTTPBody:data];

  return req;
}

@end


@implementation KSOmahaServer (Private)

+ (NSMutableDictionary *)defaultParams {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:@"10" forKey:kUpdateEngineOSVersion];
  [dict setObject:@"0" forKey:kUpdateEngineIsMachine];
  return dict;
}

- (void)setupActives {

  // Populate the actives with all the stored dates, which is a dictionary
  // keyed by productID containing the interesting dates.
  NSDictionary *params = [self params];
  NSDictionary *activesInfos =
    [params objectForKey:kUpdateEngineProductActiveInfoKey];
  NSEnumerator *activeKeyEnumerator = [activesInfos keyEnumerator];
  NSString *productID;

  actives_ = [[KSClientActives alloc] init];
  while ((productID = [activeKeyEnumerator nextObject])) {
    NSDictionary *perProductInfo = [activesInfos objectForKey:productID];
    NSDate *lastRollCall =
      [perProductInfo objectForKey:kUpdateEngineLastRollCallPingDate];
    NSDate *lastPing =
      [perProductInfo objectForKey:kUpdateEngineLastActivePingDate];
    NSDate *lastActive =
      [perProductInfo objectForKey:kUpdateEngineLastActiveDate];
    [actives_ setLastRollCallPing:lastRollCall
                   lastActivePing:lastPing
                       lastActive:lastActive
                     forProductID:productID];
  }
}

// The resulting XML document will look something like the following:
/*

 <?xml version="1.0" encoding="UTF-8"?>
 <o:gupdate xmlns:o="http://www.google.com/update2/request"
            version="UpdateEngine-0.1.4.0"
            protocol="2.0"
            ismachine="0">

   <o:os version="MacOSX" platform="mac" sp="10"></o:os>

   <o:app appid="com.google.test2">
     <o:ping a="1" r="1"></o:ping>
     <o:event errorcode="1"></o:event>
   </o:app>

   <o:app appid="com.google.test3">
     <o:ping a="-1" r="1"></o:ping>
   </o:app>

   <o:kstat baz="-1" foo="1" bar="1"></o:kstat>

 </o:gupdate>

 */
- (void)buildDocumentForStats:(KSStatsCollection *)stats {
  if (stats == nil) return;

  [self createRootAndDocument];

  NSXMLElement *kstat = [NSXMLNode elementWithName:@"o:kstat"];

  NSDictionary *statsDict = [stats statsDictionary];
  NSEnumerator *statEnumerator = [statsDict keyEnumerator];
  NSString *statKey = nil;

  // Iterate all of the stats in |statsDict|
  //   for each stat that is a per-product stat, add it to a <o:app> element
  //   for each stat that is machine-wide, add it to the <o:kstat> element
  while ((statKey = [statEnumerator nextObject])) {
    if (KSIsProductStatKey(statKey)) {
      // Handle the per-product stats
      NSString *product = KSProductFromStatKey(statKey);
      NSString *stat = KSStatFromStatKey(statKey);

      NSXMLElement *app = [self elementForApp:product];

      if ([stat isEqualToString:kStatInstallRC]) {
        // If this per-product stat is "kStatInstallRC", then add an event
        // element to record the errorcode (this is basically sending up the
        // return value from this app's update's return code).
        NSString *value = [[stats numberForStat:statKey] stringValue];
        // Build the per-app XML element for this app
        [self addElement:@"o:event"
           withAttribute:@"errorcode"
             stringValue:value
                toParent:app];
      }

      // Add this app element to the root node if necessary
      if ([app parent] == nil)
        [root_ addChild:app];

    } else {
      // Handle the machine-wide stat by adding an attribute to the
      // <o:kstat> element

      NSString *statValue = [[stats numberForStat:statKey] stringValue];
      NSXMLNode *statAttribute = [NSXMLNode attributeWithName:statKey
                                                  stringValue:statValue];
      [kstat addAttribute:statAttribute];
    }
  }

  [root_ addChild:kstat];
}

// Helper to return the version of our bundle as an NSString.
- (NSString *)bundleVersion {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  if (bundle) {
    NSDictionary *info = [bundle infoDictionary];
    NSString *version = [info objectForKey:(NSString*)kCFBundleVersionKey];
    return version;
  }
  GTMLoggerDebug(@"No bundle version found");  // COV_NF_LINE
  // found nothing!
  return @"0";  // COV_NF_LINE
}

/*
<?xml version="1.0" encoding="UTF-8"?>
<o:gupdate xmlns:o="http://www.google.com/update2/request" version="UpdateEngine-1.0"
    protocol="2.0"
    ismachine="1">
  <o:os version="MacOSX" platform="mac" sp="10.5.2_x86"></o:os>

    ...right here: filled in via -elementFromTicket, lower...

</o:gupdate>
*/
- (void)createRootAndDocument {
  if (document_) {
    [document_ release];  // owner of root_
    root_ = nil;
    document_ = nil;
  }
  root_ = [NSXMLNode elementWithName:@"o:gupdate"];  // root_ owned by document_
  NSString *xmlns = @"http://www.google.com/update2/request";
  [root_ addAttribute:[NSXMLNode attributeWithName:@"xmlns:o"
                                       stringValue:xmlns]];

  NSString *identity = [[self params] objectForKey:kUpdateEngineIdentity];
  if (!identity) identity = @"UpdateEngine";
  NSString *version = [NSString stringWithFormat:@"%@-%@",
                                identity, [self bundleVersion]];
  [root_ addAttribute:[NSXMLNode attributeWithName:@"version"
                                       stringValue:version]];
  [root_ addAttribute:[NSXMLNode attributeWithName:@"protocol"
                                       stringValue:@"2.0"]];

  NSString *ismachine = [[self params] objectForKey:kUpdateEngineIsMachine];
  [root_ addAttribute:[NSXMLNode attributeWithName:@"ismachine"
                                 stringValue:ismachine]];
  // 'tag' is optional; it may be nil.
  NSString *tag = [[self params] objectForKey:kUpdateEngineUpdateCheckTag];
  if (tag) [root_ addAttribute:[NSXMLNode attributeWithName:@"tag"
                                                stringValue:tag]];

  NSXMLElement *child = [NSXMLNode elementWithName:@"o:os"];
  [child addAttribute:[NSXMLNode attributeWithName:@"version"
                                       stringValue:@"MacOSX"]];
  [child addAttribute:[NSXMLNode attributeWithName:@"platform"
                                       stringValue:@"mac"]];
  // Omaha convention: OS version is "5" (XP) or "6" (Vista)
  // "sp" (service pack) for OS minor version (e.g. 1, 2, etc).
  // UpdateEngine convention: OS version is "MacOSX"
  // "sp" is full version number with an arch appended (e.g. "10.5.2_x86")
  NSString *sp = [[self params] objectForKey:kUpdateEngineOSVersion];
  [child addAttribute:[NSXMLNode attributeWithName:@"sp"
                                       stringValue:sp]];
  [root_ addChild:child];

  document_ = [[NSXMLDocument alloc] initWithRootElement:root_];
}

- (NSXMLElement *)elementForApp:(NSString *)appID {
  if (appID == nil) return nil;

  // We first check to see if we can find a child element of |root_| which has
  // "appid" == |appID|, if we find one, we return that one. Otherwise, we
  // create a new app element with the requested appid.

  NSError *error = nil;
  NSString *xpath = [NSString stringWithFormat:@".//app[@appid='%@']", appID];
  NSArray *nodes = [root_ nodesForXPath:xpath error:&error];
  if (error) {
    GTMLoggerError(@"XPath ('%@') failed with error %@", xpath, error);  // COV_NF_LINE
  }

  NSXMLElement *app = nil;
  if ([nodes count] > 0) {
    app = [nodes objectAtIndex:0];
  }

  if (app == nil) {
    app = [NSXMLNode elementWithName:@"o:app"];
    [app addAttribute:[NSXMLNode attributeWithName:@"appid" stringValue:appID]];
  }
  return app;
}

- (void)addPingElementForProductID:(NSString *)productID
                          toParent:(NSXMLElement *)parent {
  int rollcallDays = [actives_ rollCallDaysForProductID:productID];
  int activeDays = [actives_ activeDaysForProductID:productID];

  if (rollcallDays == kKSClientActivesDontReport &&
      activeDays == kKSClientActivesDontReport) {
    // No ping.
    return;
  }

  NSXMLElement *ping = [NSXMLNode elementWithName:@"o:ping"];
  // The "r=#" attribute is the number of days since the last roll-call
  // ping.
  if (rollcallDays != kKSClientActivesDontReport) {
    NSString *rollcallString = [NSString stringWithFormat:@"%d", rollcallDays];
    [ping addAttribute:[NSXMLNode attributeWithName:@"r"
                                        stringValue:rollcallString]];
    [actives_ sentRollCallForProductID:productID];
  }
  // The "a=#" attribute is the number of days since the last active ping.
  if (activeDays != kKSClientActivesDontReport) {
    NSString *activeString = [NSString stringWithFormat:@"%d", activeDays];
    [ping addAttribute:[NSXMLNode attributeWithName:@"a"
                                       stringValue:activeString]];
    [actives_ sentActiveForProductID:productID];
  }
  [parent addChild:ping];
}

- (NSXMLElement *)elementFromTicket:(KSTicket *)t {
  NSXMLElement *el = [self elementForApp:[t productID]];
  [el addAttribute:[NSXMLNode attributeWithName:@"version"
                                    stringValue:[t determineVersion]]];
  [el addAttribute:[NSXMLNode attributeWithName:@"lang" stringValue:@"en-us"]];
  // Set the "install age", as determined by the ticket's creation date.
  NSDate *creationDate = [t creationDate];
  // |creationDate| should be non-nil, but avoid getting a potentially bad
  // value from a double-sized return from a nil message send, just in case.
  if (creationDate) {
    NSTimeInterval ticketAge = [creationDate timeIntervalSinceNow];
    // Don't use creation dates from the future.
    if (ticketAge < 0) {
      const int kSecondsPerDay = 24 * 60 * 60;
      int ageInDays = (int)(ticketAge / -kSecondsPerDay);
      NSString *age = [NSString stringWithFormat:@"%d", ageInDays];
      [el addAttribute:[NSXMLNode attributeWithName:@"installage"
                                        stringValue:age]];
    }
  }
  if ([[[self params] objectForKey:kUpdateEngineUserInitiated] boolValue]) {
    [el addAttribute:[NSXMLNode attributeWithName:@"installsource"
                                      stringValue:@"ondemandupdate"]];
  }

  NSString *tag = [t determineTag];
  if (tag)
    [el addAttribute:[NSXMLNode attributeWithName:@"tag"
                                      stringValue:tag]];
  NSString *brand = [t determineBrand];
  if (!brand) brand = DEFAULT_BRAND_CODE;
  [el addAttribute:[NSXMLNode attributeWithName:@"brand"
                                    stringValue:brand]];

  // Adds o:ping element.
  [self addPingElementForProductID:[t productID]
                          toParent:el];

  NSString *ttTokenString = nil;
  NSString *ttTokenValue = [t trustedTesterToken];
  if (ttTokenValue)
    ttTokenString = @"tttoken";

  [self addElement:@"o:updatecheck" withAttribute:ttTokenString
       stringValue:ttTokenValue toParent:el];

  return el;
}

- (NSXMLElement *)addElement:(NSString *)name withAttribute:(NSString *)attr
                 stringValue:(NSString *)value toParent:(NSXMLElement *)parent {
  NSXMLElement *child = [NSXMLNode elementWithName:name];
  if (attr && value)
    [child addAttribute:[NSXMLNode attributeWithName:attr stringValue:value]];
  [parent addChild:child];
  return child;
}

// Warning: NSData is not a c-string; it is not NULL-terminated.
- (NSData *)dataFromDocument {
  NSString *header = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
  NSData *xml = [document_ XMLDataWithOptions:NSXMLNodePrettyPrint];
  NSMutableData *data = [NSMutableData dataWithCapacity:([xml length] +
                                                         [header length])];
  [data appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
  [data appendData:xml];
  return data;
}

// Given an NSXMLNode, returns a dictionary containing all of the node's
// attributes and attribute values as NSStrings.
- (NSMutableDictionary *)dictionaryWithXMLAttributesForNode:(NSXMLNode *)node {
  if (node == nil) return nil;

  NSError *error = nil;
  NSArray *attributes = [node nodesForXPath:@"./@*" error:&error];
  if ([attributes count] == 0) return nil;

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSXMLNode *attr = nil;
  NSEnumerator *attrEnumerator = [attributes objectEnumerator];

  while ((attr = [attrEnumerator nextObject])) {
    [dict setObject:[attr stringValue]
             forKey:[attr name]];
  }

  return dict;
}

// Given a dictionary of key/value pair attributes, returns the corresponding
// KSUpdateInfo object. We basically do this by converting some of the values in
// |attributes| to more appropriate types (e.g., an NSString representing a URL
// into an actual NSURL), and verifying that required attributes are present.
//
// We also ensure that all required attributes have the known, required keys.
// For example, we don't just make sure that the Omaha server returned a
// "codebase" attribute, but we change the key to be kServerCodebaseURL, and we
// change the value to be an actual NSURL.
//
// If any errors occur, return nil.
- (KSUpdateInfo *)updateInfoWithAttributes:(NSDictionary *)attributes {
  if (attributes == nil) return nil;

  NSMutableDictionary *updateInfo = [[attributes mutableCopy] autorelease];

  // Transform "codebase" => kServerCodebaseURL, and make the value an NSURL
  NSString *codebase = [updateInfo objectForKey:@"codebase"];
  if (codebase) {
    NSURL *url = [NSURL URLWithString:codebase];
    if (url) {
      [updateInfo removeObjectForKey:@"codebase"];
      [updateInfo setObject:url forKey:kServerCodebaseURL];
    }
  }

  // Transform "size" => kServerCodeSize, and make it an NSNumber (int)
  int size = [[updateInfo objectForKey:@"size"] intValue];
  [updateInfo removeObjectForKey:@"size"];
  [updateInfo setObject:[NSNumber numberWithInt:size]
                 forKey:kServerCodeSize];

  // Transform "hash" => kServerCodeHash
  NSString *hash = [updateInfo objectForKey:@"hash"];
  if (hash) {
    [updateInfo removeObjectForKey:@"hash"];
    [updateInfo setObject:hash forKey:kServerCodeHash];
  }

  // The next couple of keys are our extensions to the Omaha server
  // protocol, via "Pair" entries in the Update Rule in the product
  // configuration file.  They are capitalized like the other rules
  // in the configuration - CamelCapWithLeadingCapitalLetterKthx.

  // Transform "Prompt" => kServerPromptUser, and make it an NSNumber (bool)
  NSString *prompt = [updateInfo objectForKey:@"Prompt"];
  if (prompt) {
    BOOL shouldPrompt = ([prompt isEqualToString:@"yes"] ||
                         [prompt isEqualToString:@"true"]);
    // Must cast BOOL to int because DO is going to transform the underlying
    // CFBoolean into an NSNumber (int) during transit anyway, and we want the
    // dict to still be "equal" after DO transfer.
    [updateInfo setObject:[NSNumber numberWithInt:(int)shouldPrompt]
                   forKey:kServerPromptUser];
  }

  // Transform "RequireReboot" => kServerRequireReboot, and make it
  // an NSNumber (bool)
  NSString *reboot = [updateInfo objectForKey:@"RequireReboot"];
  if (reboot) {
    BOOL requireReboot = ([reboot isEqualToString:@"yes"] ||
                           [reboot isEqualToString:@"true"]);
    // Must cast BOOL to int because DO is going to transform the underlying
    // CFBoolean into an NSNumber (int) during transit anyway, and we want the
    // dict to still be "equal" after DO transfer.
    [updateInfo setObject:[NSNumber numberWithInt:(int)requireReboot]
                   forKey:kServerRequireReboot];
  }

  // Transform "MoreInfo" => kServerMoreInfoURLString.
  NSString *moreinfo = [updateInfo objectForKey:@"MoreInfo"];
  if (moreinfo) {
    [updateInfo setObject:moreinfo forKey:kServerMoreInfoURLString];
  }

  // Transform "LocalizationBundle" => kServerLocalizationBundle
  NSString *localizationBundle =
    [updateInfo objectForKey:@"LocalizationBundle"];
  if (localizationBundle) {
    [updateInfo setObject:localizationBundle
                   forKey:kServerLocalizationBundle];
  }

  // Transform "DisplayVersion" => kServerDisplayVersion
  NSString *displayVersion = [updateInfo objectForKey:@"DisplayVersion"];
  if (displayVersion) {
    [updateInfo setObject:displayVersion
                   forKey:kServerDisplayVersion];
  }

  // Transform "Version" => kServerVersion
  NSString *version = [updateInfo objectForKey:@"Version"];
  if (version) {
    [updateInfo setObject:version
                   forKey:kServerVersion];
  }

  // Verify that all required keys are present
  NSArray *requiredKeys = [NSArray arrayWithObjects:
                            kServerProductID, kServerCodebaseURL,
                            kServerCodeSize, kServerCodeHash, nil];
  NSEnumerator *keyEnumerator = [requiredKeys objectEnumerator];
  NSString *key = nil;
  while ((key = [keyEnumerator nextObject])) {
    if ([updateInfo objectForKey:key] == nil) {
      GTMLoggerError(@"Missing required key '%@' in %@", key, updateInfo);
      return nil;
    }
  }

  return updateInfo;
}

// Allow URLs that match any of the following:
// - Allow everything in DEBUG builds (includes unit tests)
// - Uses a file: scheme
// - Uses https: scheme to a certain google.com subdomain
- (BOOL)isAllowedURL:(NSURL *)url {
  if (url == nil) return NO;

#ifdef DEBUG
  // Anything goes, debug style.
  return YES;
#endif

  // Disallow anything but https: urls
  if (![[url scheme] isEqualToString:@"https"])
    return NO;

  // If supplied, only allow URLs to the allowed subdomains.
  NSArray *allowedSubdomains =
    [[self params] objectForKey:kUpdateEngineAllowedSubdomains];
  if (!allowedSubdomains)
    return YES;

  NSString *host = [@"." stringByAppendingString:[url host]];
  NSPredicate *filter = [NSPredicate predicateWithFormat:
                         @"%@ ENDSWITH SELF", host];
  NSArray *matches = [allowedSubdomains filteredArrayUsingPredicate:filter];

  if ([matches count] > 0)
    return YES;

  // No match, so deny.
  return NO;
}

@end

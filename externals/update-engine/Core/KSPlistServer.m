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

#import "KSPlistServer.h"
#import "KSTicket.h"
#import "GTMLogger.h"
#import "KSUpdateInfo.h"


@interface KSPlistServer (PrivateMethods)

// Returns YES if the specified rule's Predicate evaluates to YES.
- (BOOL)shouldApplyRule:(NSDictionary *)rule;

// Returns a KSUpdateInfo instance that was created from the data in |rule|.
- (KSUpdateInfo *)updateInfoForRule:(NSDictionary *)rule;

@end


@implementation KSPlistServer

+ (id)serverWithURL:(NSURL *)url {
  return [[[self alloc] initWithURL:url params:nil] autorelease];
}

- (id)initWithURL:(NSURL *)url params:(NSDictionary *)params
           engine:(KSUpdateEngine *)engine {
  if ((self = [super initWithURL:url params:params engine:engine])) {
    systemVersion_ = [[NSDictionary alloc] initWithContentsOfFile:
                      @"/System/Library/CoreServices/SystemVersion.plist"];
    if (systemVersion_ == nil) {
      // COV_NF_START
      GTMLoggerError(@"Failed to read SystemVersion.plist, bailing.");
      [self release];
      return nil;
      // COV_NF_END
    }
  }
  return self;
}

- (void)dealloc {
  [tickets_ release];
  [systemVersion_ release];
  [super dealloc];
}

- (NSArray *)tickets {
  return tickets_;
}

//
// Implementations of abstract methods from KSServer superclass
//

- (NSArray *)requestsForTickets:(NSArray *)tickets {
  // Retain the tickets array so that we can get the tickets in the
  // updateInfosForResposne:data: method.
  [tickets_ autorelease];
  tickets_ = [tickets copy];

  NSURLRequest *request = nil;
  request = [NSURLRequest requestWithURL:[self url]
                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                         timeoutInterval:60];

  // Returns a trivial NSURLRequest to do a GET of the URL
  return [NSArray arrayWithObject:request];
}

- (NSArray *)updateInfosForResponse:(NSURLResponse *)response
                               data:(NSData *)data
                      outOfBandData:(NSDictionary **)oob {
  // We don't use |response|
  if (data == nil)
    return nil;

  // We don't return out-of-band data.
  if (oob) *oob = nil;

  // Decode the response |data| into a plist
  NSString *body = [[[NSString alloc]
                     initWithData:data
                         encoding:NSUTF8StringEncoding] autorelease];
  NSDictionary *plist = nil;
  @try {
    // This method can throw if |body| isn't a valid plist
    plist = [body propertyList];
  }
  @catch (id ex) {
    GTMLoggerError(@"Failed to parse response into plist: %@", ex);
    return nil;
  }

  // Array that we'll return
  NSMutableArray *updateInfos = [NSMutableArray array];

  // Walk through the array of "Rules" in the response plist, and create
  // KSUpdateInfos as necessary.
  NSDictionary *rule = nil;
  NSEnumerator *ruleEnumerator = [[plist objectForKey:@"Rules"]
                                  objectEnumerator];

  while ((rule = [ruleEnumerator nextObject])) {
    if ([self shouldApplyRule:rule]) {
      KSUpdateInfo *ui = [self updateInfoForRule:rule];
      if (ui) [updateInfos addObject:ui];
    }
  }

  return [updateInfos count] > 0 ? updateInfos : nil;
}

- (NSString *)prettyPrintResponse:(NSURLResponse *)response
                             data:(NSData *)data {
  return [[[NSString alloc] initWithData:data
                                encoding:NSUTF8StringEncoding] autorelease];
}

@end


@implementation KSPlistServer (PrivateMethods)

- (BOOL)shouldApplyRule:(NSDictionary *)rule {
  NSString *productID = [rule objectForKey:@"ProductID"];
  NSString *predicateString = [rule objectForKey:@"Predicate"];

  if (productID == nil || predicateString == nil)
    return NO;

  // Find the ticket with this rule's product ID.
  KSTicket *ticket = [[[self tickets] filteredArrayUsingPredicate:
                       [NSPredicate predicateWithFormat:
                        @"productID == %@", productID]] lastObject];
  if (ticket == nil)
    return NO;

  NSPredicate *predicate = nil;
  NSDictionary *predicateTarget = nil;
  BOOL matches = NO;

  @try {
    // This predicate stuff must be done in a try/catch because we're creating
    // the predicate from data supplied by the plist we fetched, and it may be
    // invalid for whatever reason.
    predicate = [NSPredicate predicateWithFormat:predicateString];

    // Create a dictionary with some useful info about the current OS and ticket
    // for the product in question. The rule's "Predicate" will be able to look
    // at this object to determine of an update is necessary.
    predicateTarget = [NSDictionary dictionaryWithObjectsAndKeys:
                          systemVersion_, @"SystemVersion",
                          ticket, @"Ticket",
                          nil];

    matches = [predicate evaluateWithObject:predicateTarget];
  }
  @catch (id ex) {
    GTMLoggerError(@"Caught exception evaluating predicate for %@: %@",
                   productID, ex);
  }

  return matches;
}

// Returns a KSUpdateInfo instance with all needed keys (see KSUpdateInfo.h).
- (KSUpdateInfo *)updateInfoForRule:(NSDictionary *)rule {
  if (rule == nil) return nil;

  // Pre-populate our KSUpdateInfo with the whole |rule|
  NSMutableDictionary *updateInfo = [[rule mutableCopy] autorelease];

  // Turn "ProductID" into kServerProductID
  NSString *pid = [updateInfo objectForKey:@"ProductID"];
  if (pid == nil) goto invalid_rule;
  [updateInfo setObject:pid forKey:kServerProductID];

  // Turn "codebase" into kServerCodebaseURL, and make the value an NSURL
  NSString *codebase = [updateInfo objectForKey:@"Codebase"];
  if (codebase == nil) goto invalid_rule;
  NSURL *url = [NSURL URLWithString:codebase];
  if (url == nil) goto invalid_rule;
  [updateInfo setObject:url forKey:kServerCodebaseURL];

  // Turn "size" into kServerCodeSize, and make it an NSNumber (int)
  NSString *sizeString = [updateInfo objectForKey:@"Size"];
  if (sizeString == nil) goto invalid_rule;
  int size = [sizeString intValue];
  [updateInfo setObject:[NSNumber numberWithInt:size]
                 forKey:kServerCodeSize];

  // Turn "hash" into kServerCodeHash
  NSString *hash = [updateInfo objectForKey:@"Hash"];
  if (hash == nil) goto invalid_rule;
  [updateInfo setObject:hash forKey:kServerCodeHash];

  return updateInfo;

invalid_rule:
  GTMLoggerError(@"Can't create KSUpdateInfo from invalid rule %@", rule);
  return nil;
}

@end

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

#import "ERDryRunCommand.h"

#import "KSUpdateEngine.h"


@implementation ERDryRunCommand

- (void)dealloc {
  [products_ release];
  [super dealloc];
}  // dealloc


- (NSString *)name {
  return @"dryrun";
}  // name


- (NSString *)blurb {
  return @"See if an update is needed, but don't install it";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Product ID for the product to update", @"productid",
                       @"Current version of the product", @"version",
                       @"Server URL", @"url",
                       nil];

}  // requiredArguments


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Existence checker path", @"xcpath",
                       nil];

}  // optionalArguments


// The way to see what products will run, but not actually install them,
// is to implement the -engine:shouldPrefetchProducts: delegate method,
// snag the products we would otherwise prefect, and then tell the engine
// to stop.  So, we'll do all the usual Update Engine setup and running here,
// and let our delegate method short-circuit things once we've figured out
// what we need to know.
- (BOOL)runWithArguments:(NSDictionary *)args {
  // Make a new ticket.
  NSString *productID = [args objectForKey:@"productid"];
  NSString *version = [args objectForKey:@"version"];
  NSString *urlString = [args objectForKey:@"url"];
  NSURL *serverURL = [NSURL URLWithString:urlString];

  // The existence checker is optional, so use a trueChecker if one isn't
  // supplied.
  NSString *xcpath = [args objectForKey:@"xcpath"];
  KSExistenceChecker *existenceChecker;
  if (xcpath == nil) {
    existenceChecker = [KSExistenceChecker trueChecker];
  } else {
    existenceChecker = [KSPathExistenceChecker checkerWithPath:xcpath];
  }

  KSTicket *ticket = [KSTicket ticketWithProductID:productID
                                           version:version
                                  existenceChecker:existenceChecker
                                         serverURL:serverURL];

  // And stick it into an in-memory ticket store.
  KSTicketStore *ticketStore = [[[KSMemoryTicketStore alloc] init] autorelease];
  [ticketStore storeTicket:ticket];

  // Make an engine to run things.  We look for Things.  Things to make us go.
  KSUpdateEngine *vroom = [KSUpdateEngine engineWithTicketStore:ticketStore
                                                       delegate:self];

  // Start the update running.
  [vroom updateProductWithProductID:productID];

  // Let Update Engine do its thing.
  while ([vroom isUpdating]) {
    NSDate *spin = [NSDate dateWithTimeIntervalSinceNow:1];
    [[NSRunLoop currentRunLoop] runUntilDate:spin];
  }

  // All done.  Report the results.
  if ([products_ count] == 0) {
    fprintf(stdout, "No products to update\n");
  } else {
    fprintf(stdout, "Products that would update:\n");

    NSEnumerator *productEnumerator = [products_ objectEnumerator];
    KSUpdateInfo *info;
    while ((info = [productEnumerator nextObject])) {
      NSString *productID = [info productID];
      fprintf(stdout, "  %s\n", [productID UTF8String]);
    }
  }

  return YES;

}  // runWithArguments

@end  // ERRunUpdateCommand


@implementation ERDryRunCommand (UpdateEngineDelegateMethods)

// Since we only care what might be updated, make a note and then tell
// Update Engine to get lost.
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldPrefetchProducts:(NSArray *)products {

  products_ = [products retain];

  [engine stopAndReset];
  return nil;

}  // shouldPrefetchProducts

@end  // UpdateEngineDelegateMethods

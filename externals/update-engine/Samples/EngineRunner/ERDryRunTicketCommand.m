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

#import "ERDryRunTicketCommand.h"

#import "KSUpdateEngine.h"


@implementation ERDryRunTicketCommand

- (void)dealloc {
  [products_ release];
  [super dealloc];
}  // dealloc


- (NSString *)name {
  return @"dryrunticket";
}  // name


- (NSString *)blurb {
  return @"See available updates in a ticket store but don't install any";
}  // blurb


- (NSDictionary *)requiredArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Path to the ticket store", @"store",
                       nil];

}  // requiredArguments


- (NSDictionary *)optionalArguments {
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"Only check for an update for this product ID",
                       @"productid",
                       nil];

}  // optionalArguments


// The way to see what products will run, but not actually install them,
// is to implement the -engine:shouldPrefetchProducts: delegate method,
// snag the products we would otherwise prefect, and then tell the engine
// to stop.  So, we'll do all the usual Update Engine setup and running here,
// and let our delegate method short-circuit things once we've figured out
// what we need to know.
- (BOOL)runWithArguments:(NSDictionary *)args {
  // Pick up the ticket store.
  NSString *storePath = [args objectForKey:@"store"];
  KSTicketStore *ticketStore = [KSTicketStore ticketStoreWithPath:storePath];

  // Make an engine to run things.
  KSUpdateEngine *vroom = [KSUpdateEngine engineWithTicketStore:ticketStore
                                                       delegate:self];

  // Optional argument, if we want to do the update check for just one product
  // rather than everything in the store.
  NSString *productID = [args objectForKey:@"productid"];

  if (productID == nil) {
    [vroom updateAllProducts];
  } else {
    [vroom updateProductWithProductID:productID];
  }

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


@implementation ERDryRunTicketCommand (UpdateEngineDelegateMethods)

// Since we only care what might be updated, make a note and then tell
// Update Engine to get lost.
- (NSArray *)engine:(KSUpdateEngine *)engine
  shouldPrefetchProducts:(NSArray *)products {

  products_ = [products retain];

  [engine stopAndReset];
  return nil;

}  // shouldPrefetchProducts

@end  // UpdateEngineDelegateMethods
